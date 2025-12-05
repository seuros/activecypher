# frozen_string_literal: true

require 'async'
require 'io/endpoint'
require 'io/endpoint/host_endpoint'
require 'io/endpoint/ssl_endpoint'

require 'io/stream'
require 'socket'
require 'stringio'

module ActiveCypher
  module Bolt
    class Connection
      include VersionEncoding

      attr_reader :host, :port, :timeout_seconds, :socket,
                  :protocol_version, :server_agent, :connection_id, :adapter,
                  :count

      # Override inspect to redact sensitive information
      def inspect
        filtered_auth = ActiveCypher::Redaction.filter_hash(@auth_token)

        attributes = {
          host: @host.inspect,
          port: @port.inspect,
          auth_token: filtered_auth.inspect,
          timeout_seconds: @timeout_seconds.inspect,
          secure: @secure.inspect,
          verify_cert: @verify_cert.inspect,
          connected: @connected.inspect,
          protocol_version: @protocol_version.inspect,
          server_agent: @server_agent.inspect,
          connection_id: @connection_id.inspect
        }

        "#<#{self.class.name}:0x#{object_id.to_s(16)} #{attributes.map { |k, v| "@#{k}=#{v}" }.join(', ')}>"
      end

      SUPPORTED_VERSIONS = [5.8, 5.2].freeze

      # Initializes a new Bolt connection.
      #
      # @param host [String] the database host
      # @param port [Integer] the database port
      # @param adapter [Object] the adapter using this connection
      # @param auth_token [Hash] authentication token
      # @param timeout_seconds [Integer] connection timeout in seconds
      # @param secure [Boolean] whether to use SSL
      # @param verify_cert [Boolean] whether to verify SSL certificates
      #
      # @note The ceremony required to instantiate a connection. Because nothing says “enterprise” like 8 arguments.
      def initialize(host, port, adapter,
                     auth_token:, timeout_seconds: 15,
                     secure: false, verify_cert: true)
        @host               = host
        @port               = port
        @auth_token         = auth_token
        @timeout_seconds    = timeout_seconds
        @secure             = secure
        @verify_cert        = verify_cert
        @adapter            = adapter

        @socket             = nil
        @connected          = false
        @protocol_version   = nil
        @server_agent       = nil
        @connection_id      = nil
        @reconnect_attempts = 0
        @max_reconnect_attempts = 3
        @count = 0
      end

      # ───────────────────────── connection lifecycle ────────────── #

      # Establishes the connection to the database.
      #
      # @raise [ConnectionError] if the connection fails
      #
      # @note Attempts to connect, or at least to feel something.
      def connect
        return if connected?

        # Using a variable to track errors instead of re-raising inside the Async block
        error = nil

        begin
          Sync do |task|
            task.with_timeout(@timeout_seconds) do
              @socket = open_socket
              perform_handshake
              @connected          = true
              @reconnect_attempts = 0
            end
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
                 SocketError, OpenSSL::SSL::SSLError => e
            # Catch connection errors inside the task
            close
            # Store the error instead of raising
            error = ConnectionError.new("Failed to connect to #{host}:#{port} - #{e.message}")
          rescue StandardError => e
            # Catch any other errors inside the task
            close
            # Store the error instead of raising
            error = ConnectionError.new("Error during connection: #{e.message}")
          end
        rescue Async::TimeoutError => e
          error = ConnectionError.new("Connection timed out to #{host}:#{port} - #{e.message}")
        rescue StandardError => e
          close
          error = ConnectionError.new("Connection error: #{e.message}")
        end

        # After the Async block is complete, raise the error if one occurred
        raise error if error
      end

      # Writes raw bytes directly to the socket.
      #
      # @param bytes [String] the bytes to write
      # @raise [ConnectionError] if the socket is not open
      #
      # @note Because sometimes you just want to feel close to the metal.
      def write_raw(bytes)
        raise ConnectionError, 'Socket not open for writing' unless socket_open?

        @socket.write(bytes) # Async::IO::Socket yields if blocked.
      rescue IOError, Errno::EPIPE => e
        close
        raise ConnectionError, "Connection lost during raw write: #{e.message}"
      end

      # Closes the TCP connection if it's open.
      #
      # @note The digital equivalent of ghosting.
      def close
        @socket.close if connected?
      rescue IOError
      ensure
        @socket = nil
        @connected = false
      end

      # Checks if the connection is open and the socket is alive.
      #
      # @return [Boolean]
      # @note Checks if we're still pretending to be connected.
      def connected? = @connected && socket_open?

      # Attempts to reconnect if the connection is lost.
      #
      # @return [Boolean] True if reconnection was successful, false otherwise
      # @note Attempts to reconnect, because hope springs eternal.
      def reconnect
        return true if connected?

        @reconnect_attempts += 1
        if @reconnect_attempts <= @max_reconnect_attempts
          close
          begin
            connect
            # Reset reconnect counter on successful connection
            @reconnect_attempts = 0
            true
          rescue ConnectionError => e
            # Log the error but don't raise
            puts "Reconnection attempt #{@reconnect_attempts}/#{@max_reconnect_attempts} failed: #{e.message}" if ENV['DEBUG']
            # Sleep to avoid hammering the server
            sleep(0.1 * @reconnect_attempts)
            false
          end
        else
          # Reset the counter after max attempts to allow future reconnects
          @reconnect_attempts = 0
          false
        end
      end

      # Writes data to the socket.
      #
      # @param data [String] the data to write
      # @raise [ConnectionError] if not connected or write fails
      #
      # @note Because nothing says "robust" like a method that can explode at any time.
      def write(data)
        raise ConnectionError, 'Not connected' unless connected?

        @socket.write(data)
      rescue Errno::EPIPE, IOError => e
        close
        raise ConnectionError, "Connection lost during write: #{e.message}"
      end

      # Reads data from the socket.
      #
      # @param length [Integer] number of bytes to read
      # @raise [ConnectionError] if not connected or read fails
      #
      # @note Reading from the void, hoping something meaningful comes back.
      def read(length)
        raise ConnectionError, 'Not connected' unless connected?

        @socket.read_exactly(length)
      rescue EOFError, Errno::ECONNRESET, Errno::EPIPE, IOError => e
        close
        raise ConnectionError, "Connection lost during read: #{e.message}"
      end

      # Debug output for those who enjoy hexadecimal existentialism.
      #
      # @param label [String]
      # @param bytes [String]
      def dump(label, bytes)
        puts "[DEBUG] #{label.ljust(18)}: #{bytes.bytes.map { |b| b.to_s(16).rjust(2, '0') }.join(' ')}" if ENV['DEBUG']
      end

      # A single Bolt socket is strictly single‑plex:
      #
      # @return [Integer] always 1, because concurrency is for people with more optimistic protocols.
      def concurrency = 1

      # Re‑use only if still alive:
      #
      # @return [Boolean]
      def reusable?   = connected?

      # Increment the usage counter for compatibility with Async::Pool diagnostics.
      def mark_used! = @count += 1

      # This method is required by Async::Pool to check if the connection is viable for reuse
      #
      # @return [Boolean]
      # @note The database equivalent of "are you still there?"
      def viable?
        return false unless connected?

        # Use the health check method to determine viability
        health = health_check

        if health[:healthy]
          true
        else
          # If health check failed, close the connection
          close
          false
        end
      end

      # Performs the Bolt handshake sequence.
      #
      # @raise [ProtocolError, ConnectionError] on failure
      #
      # @note The digital equivalent of a secret handshake, but with more bytes and less trust.
      def perform_handshake
        # Bolt Magic Preamble (0x6060B017)
        magic = "\x60\x60\xB0\x17"
        dump('Magic', magic)
        write_raw(magic)

        # Proposed Bolt Versions (ordered by preference)
        # Encoded as 4‑byte big‑endian integers
        proposed_versions = (SUPPORTED_VERSIONS + [0, 0])[0, 4]
        versions = proposed_versions.map { |v| encode_version(v) }.join
        dump('Sending versions', versions)
        write_raw(versions)

        # Read agreed version (4 bytes)
        agreed_version_bytes = read_raw(4)
        dump('Agreed version', agreed_version_bytes)
        @protocol_version = decode_version(agreed_version_bytes)

        # Validate agreed version
        unless SUPPORTED_VERSIONS.include?(@protocol_version)
          close
          raise ProtocolError,
                "Server only supports unsupported Bolt protocol (#{@protocol_version}). This client requires one of: #{SUPPORTED_VERSIONS.join(', ')}"
        end

        # Send HELLO message
        send_hello

        # Read response (should be SUCCESS or FAILURE)
        response = begin
          msg = read_message
          msg
        rescue EOFError => e
          raise ConnectionError, "Server closed connection: #{e.message}"
        end

        case response
        when Messaging::Success
          handle_hello_success(response.metadata)

          # if auth credentials were provided, send LOGON
          send_logon if @auth_token && @auth_token[:scheme] == 'basic'

          # Let adapter create protocol handler instead of directly instantiating
          @protocol_handler = @adapter.create_protocol_handler(self)
        when Messaging::Failure
          handle_hello_failure(response.metadata)
        else
          close
          raise ProtocolError, "Unexpected response during handshake: #{response.class}"
        end
      rescue ConnectionError, ProtocolError => e
        close
        raise e
      rescue StandardError => e
        close
        raise ConnectionError, "Handshake error: #{e.message}"
      end

      # Sends the HELLO message.
      #
      # @note Because every protocol needs a little small talk before the pain begins.
      def send_hello
        user_agent = "ActiveCypher::Bolt/#{ActiveCypher::VERSION} (Ruby/#{RUBY_VERSION})"
        platform = RUBY_DESCRIPTION.split[1..].join(' ') # Gets everything after "ruby" in RUBY_DESCRIPTION
        metadata = {
          'user_agent' => user_agent,
          'notifications_minimum_severity' => 'WARNING',
          'bolt_agent' => {
            'product' => user_agent,
            'platform' => platform,
            'language' => "#{RUBY_PLATFORM}/#{RUBY_VERSION}",
            'language_details' => "#{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}"
          }
        }
        hello_message = Messaging::Hello.new(metadata)
        write_message(hello_message, 'HELLO')
      end

      # Sends the LOGON message.
      #
      # @note Because authentication is just another opportunity for disappointment.
      def send_logon
        # Get credentials from the connection's auth token
        metadata = {
          'scheme' => @auth_token[:scheme],
          'principal' => @auth_token[:principal],
          'credentials' => @auth_token[:credentials]
        }

        # Create and send LOGON message
        begin
          logon_msg = Messaging::Logon.new(metadata)
          write_message(logon_msg, 'LOGON')

          # Read and process response
          logon_response = read_message

          case logon_response
          when Messaging::Success
            true
          when Messaging::Failure
            code = logon_response.metadata['code']
            message = logon_response.metadata['message']
            close
            raise ConnectionError, "Authentication failed during LOGON: #{code} - #{message}"
          else
            close
            raise ProtocolError, "Unexpected response to LOGON: #{logon_response.class}"
          end
        rescue StandardError => e
          close
          raise ConnectionError, "Authentication error: #{e.message}"
        end
      end

      # Handles a SUCCESS response to HELLO.
      #
      # @note The rarest of all outcomes.
      def handle_hello_success(metadata)
        @connection_id = metadata['connection_id']
        @server_agent  = metadata['server']
      end

      # Handles a FAILURE response to HELLO.
      #
      # @note The more common outcome.
      def handle_hello_failure(metadata)
        code    = metadata['code']
        message = metadata['message']
        close
        raise ConnectionError, "Authentication failed: #{code} - #{message}"
      end

      # Writes a Bolt message using the MessageWriter, adding Bolt chunking.
      #
      # @param message [Object] the Bolt message to write
      # @param debug_label [String, nil] optional debug label
      # @raise [ProtocolError] if writing fails
      #
      # @note Because nothing says "enterprise" like chunked binary messages.
      def write_message(message, debug_label = nil)
        raise ConnectionError, 'Socket not open for writing' unless socket_open?

        if message.is_a?(ActiveCypher::Bolt::Messaging::Run)
          dump '→ RUN', " #{message.fields[0]} #{message.fields[2].inspect}" # query & metadata
        end
        # 1. Pack the message into a temporary buffer
        message_io = StringIO.new(+'', 'wb')
        writer = MessageWriter.new(message_io)
        writer.write(message)
        message_bytes = message_io.string
        message_size = message_bytes.bytesize

        # Debug output if a label was provided
        dump(debug_label, message_bytes) if debug_label

        # 2. Write the chunk header and data
        chunk_header = [message_size].pack('n')
        write_raw(chunk_header)
        write_raw(message_bytes)
        write_raw("\x00\x00") # Chunk terminator

        # Ensure everything is sent
        @socket.flush
      rescue StandardError => e
        close
        raise ProtocolError, "Failed to write message: #{e.message}"
      end

      # Reads a Bolt message using the MessageReader.
      #
      # @return [Object] the Bolt message
      # @raise [ConnectionError, ProtocolError] if reading fails
      #
      # @note Reads from the abyss and hopes for a message, not a void.
      def read_message
        raise ConnectionError, 'Socket not open for reading' unless socket_open?

        reader = MessageReader.new(@socket)
        reader.read_message
      rescue ConnectionError, ProtocolError => e
        close
        raise e
      rescue EOFError => e
        close
        raise ConnectionError, "Connection closed unexpectedly: #{e.message}"
      end

      # Access to the protocol handler
      attr_reader :protocol_handler

      # Resets the connection state.
      #
      # @return [Boolean] true if reset succeeded, false otherwise
      # @note For when you want to pretend nothing ever happened.
      def reset!
        return false unless connected?

        begin
          write_message(ActiveCypher::Bolt::Messaging::Reset.new)
          msg = read_message # should be Messaging::Success
          msg.is_a?(ActiveCypher::Bolt::Messaging::Success)
        rescue ConnectionError, ProtocolError
          # If reset fails, close the connection
          close
          false
        rescue StandardError
          # For any other errors, also close the connection
          close
          false
        end
      end

      # Returns a fresh Session object that re‑uses this TCP/Bolt socket.
      #
      # @param **kwargs passed to the Session initializer
      # @return [Bolt::Session]
      # @note Because every connection deserves a second chance.
      def session(**)
        Bolt::Session.new(self, **)
      end

      # Synchronously execute a read transaction.
      def read_transaction(db: nil, timeout: nil, metadata: nil, &)
        session(database: db).read_transaction(db: db, timeout: timeout, metadata: metadata, &)
      end

      # Synchronously execute a write transaction.
      def write_transaction(db: nil, timeout: nil, metadata: nil, &)
        session(database: db).write_transaction(db: db, timeout: timeout, metadata: metadata, &)
      end


      # ────────────────────────────────────────────────────────────────────
      # HEALTH AND VERSION DETECTION METHODS
      # ────────────────────────────────────────────────────────────────────

      # Returns parsed version information from the server agent string.
      #
      # @return [Hash] version information with :database_type, :version, :major, :minor, :patch
      # @note Extracts version from server_agent captured during handshake
      def version
        return @version if defined?(@version)

        @version = parse_version_from_server_agent
      end

      # Returns the database type detected from server agent.
      #
      # @return [Symbol] :neo4j, :memgraph, or :unknown
      def database_type
        version[:database_type]
      end

      # Performs a health check using database-appropriate queries.
      #
      # @return [Hash] health check result with :healthy, :response_time_ms, :details
      # @note Uses different queries based on detected database type
      def health_check
        return { healthy: false, response_time_ms: nil, details: 'Not connected' } unless connected?

        result = nil

        begin
          result = Sync do
            case database_type
            when :neo4j
              perform_neo4j_health_check
            when :memgraph
              perform_memgraph_health_check
            else
              perform_generic_health_check
            end
          end

          result
        rescue ConnectionError, ProtocolError => e
          { healthy: false, response_time_ms: nil, details: "Health check failed: #{e.message}" }
        end
      end

      # Returns comprehensive database information.
      #
      # @return [Hash] database information including version, health, and system details
      def database_info
        info = version.dup
        health = health_check

        info.merge({
                     healthy: health[:healthy],
                     response_time_ms: health[:response_time_ms],
                     server_agent: @server_agent,
                     connection_id: @connection_id,
                     protocol_version: @protocol_version
                   })
      end

      # Returns server/cluster status information (when available).
      #
      # @return [Array<Hash>, nil] array of server status objects or nil if not supported
      def server_status
        return nil unless connected?

        begin
          case database_type
          when :neo4j
            get_neo4j_server_status
          when :memgraph
            get_memgraph_server_status
          else
            nil
          end
        rescue ConnectionError, ProtocolError
          nil # Gracefully handle unsupported operations
        end
      end

      # ────────────────────────────────────────────────────────────────────
      # PRIVATE HELPER METHODS
      # ────────────────────────────────────────────────────────────────────
      private

      # Opens a non‑blocking TCP socket wrapped by Async.
      #
      # @return [IO::Stream] the opened socket
      # @raise [ConnectionError] if connection fails
      # @note Because blocking is for people who like waiting.
      def open_socket
        endpoint =
          if @secure
            ctx             = OpenSSL::SSL::SSLContext.new
            ctx.verify_mode = @verify_cert ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
            IO::Endpoint.ssl(@host, @port,
                             ssl_context: ctx,
                             hostname: @host)
          else
            IO::Endpoint.tcp(@host, @port)
          end

        # Ensure all exceptions are caught and wrapped appropriately
        begin
          endpoint.connect.then { |io| IO::Stream(io) }
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
          close
          # Let the error propagate up to the connect method
          raise ConnectionError, "Failed to connect to #{host}:#{port} - #{e.message}"
        rescue StandardError => e
          close
          # Let the error propagate up to the connect method
          raise ConnectionError, "Unexpected error connecting to #{host}:#{port} - #{e.message}"
        end
      end

      # Reads exactly n raw bytes from the socket.
      #
      # @param n [Integer] number of bytes to read
      # @return [String] the bytes read
      # @raise [ConnectionError] if the socket is not open or read fails
      # @note Because sometimes you want exactly n bytes, not a byte more, not a byte less.
      def read_raw(n)
        raise ConnectionError, 'Socket not open for reading' unless socket_open?

        data = @socket.read_exactly(n) # Will yield until n bytes ready.
        raise EOFError, "Connection closed while reading #{n} bytes" if data.nil?
        raise ProtocolError, "Expected #{n} bytes, got #{data.bytesize}" if data.bytesize != n

        data
      rescue EOFError, Errno::ECONNRESET, Errno::EPIPE, IOError => e
        close
        raise ConnectionError, "Connection lost during raw read: #{e.message}"
      end

      # Internal check if the socket exists and is not closed.
      #
      # @return [Boolean]
      # @note The Schrödinger's cat of sockets.
      def socket_open? = @socket && !@socket.closed?

      # ────────────────────────────────────────────────────────────────────
      # HEALTH AND VERSION DETECTION HELPERS
      # ────────────────────────────────────────────────────────────────────

      # Parses version information from the server_agent string.
      #
      # @return [Hash] parsed version information
      def parse_version_from_server_agent
        return default_version_info unless @server_agent

        case @server_agent
        when %r{^Neo4j/(\d+\.\d+(?:\.\d+)?)}i
          version_string = ::Regexp.last_match(1)
          parts = version_string.split('.').map(&:to_i)
          {
            database_type: :neo4j,
            version: version_string,
            major: parts[0] || 0,
            minor: parts[1] || 0,
            patch: parts[2] || 0
          }
        when %r{^Memgraph/(\d+\.\d+(?:\.\d+)?)}i
          version_string = ::Regexp.last_match(1)
          parts = version_string.split('.').map(&:to_i)
          {
            database_type: :memgraph,
            version: version_string,
            major: parts[0] || 0,
            minor: parts[1] || 0,
            patch: parts[2] || 0
          }
        when /.*Memgraph/i
          # Handle Memgraph server agent: "Neo4j/v5.11.0 compatible graph database server - Memgraph"
          if @server_agent =~ %r{Neo4j/v(\d+\.\d+(?:\.\d+)?)}
            version_string = ::Regexp.last_match(1)
            parts = version_string.split('.').map(&:to_i)
            {
              database_type: :memgraph,
              version: version_string,
              major: parts[0] || 0,
              minor: parts[1] || 0,
              patch: parts[2] || 0
            }
          else
            {
              database_type: :memgraph,
              version: 'unknown',
              major: 0,
              minor: 0,
              patch: 0
            }
          end
        else
          {
            database_type: :unknown,
            version: @server_agent,
            major: 0,
            minor: 0,
            patch: 0
          }
        end
      end

      # Returns default version info when server_agent is not available.
      #
      # @return [Hash] default version information
      def default_version_info
        {
          database_type: :unknown,
          version: 'unknown',
          major: 0,
          minor: 0,
          patch: 0
        }
      end

      # Performs Neo4j-specific health check using RETURN 1 (fallback from db.ping).
      #
      # @return [Hash] health check result
      def perform_neo4j_health_check
        start_time = Time.now

        begin
          write_message(Messaging::Run.new('RETURN 1 AS result', {}, {}), 'HEALTH_CHECK')
          run_response = read_message

          case run_response
          when Messaging::Success
            # Send PULL message to complete the transaction
            write_message(Messaging::Pull.new({ 'n' => -1 }), 'PULL')

            # Read messages until we get SUCCESS or FAILURE
            response_time = nil
            loop do
              msg = read_message
              case msg
              when Messaging::Record
                # Skip records, we just want to know if the query succeeded
                next
              when Messaging::Success
                response_time = ((Time.now - start_time) * 1000).round(2)
                return { healthy: true, response_time_ms: response_time, details: 'RETURN 1 succeeded' }
              when Messaging::Failure
                return { healthy: false, response_time_ms: nil, details: 'RETURN 1 failed with error' }
              else
                return { healthy: false, response_time_ms: nil, details: 'RETURN 1 unexpected response' }
              end
            end
          else
            { healthy: false, response_time_ms: nil, details: 'RETURN 1 run failed' }
          end
        ensure
          # Reset connection state after health check
          reset!
        end
      end

      # Performs Memgraph-specific health check using SHOW STORAGE INFO.
      #
      # @return [Hash] health check result
      def perform_memgraph_health_check
        start_time = Time.now

        begin
          write_message(Messaging::Run.new('SHOW STORAGE INFO', {}, {}), 'HEALTH_CHECK')
          run_response = read_message

          case run_response
          when Messaging::Success
            # Send PULL message to complete the transaction
            write_message(Messaging::Pull.new({ 'n' => -1 }), 'PULL')

            # Read messages until we get SUCCESS or FAILURE
            response_time = nil
            loop do
              msg = read_message
              case msg
              when Messaging::Record
                # Skip records, we just want to know if the query succeeded
                next
              when Messaging::Success
                response_time = ((Time.now - start_time) * 1000).round(2)
                return { healthy: true, response_time_ms: response_time, details: 'SHOW STORAGE INFO succeeded' }
              when Messaging::Failure
                return { healthy: false, response_time_ms: nil, details: 'SHOW STORAGE INFO failed with error' }
              else
                return { healthy: false, response_time_ms: nil, details: 'SHOW STORAGE INFO unexpected response' }
              end
            end
          else
            { healthy: false, response_time_ms: nil, details: 'SHOW STORAGE INFO run failed' }
          end
        ensure
          # Reset connection state after health check
          reset!
        end
      end

      # Performs generic health check using simple RETURN 1 query.
      #
      # @return [Hash] health check result
      def perform_generic_health_check
        start_time = Time.now

        begin
          write_message(Messaging::Run.new('RETURN 1', {}, {}), 'HEALTH_CHECK')
          run_response = read_message

          case run_response
          when Messaging::Success
            # Send PULL message to complete the transaction
            write_message(Messaging::Pull.new({ 'n' => -1 }), 'PULL')

            # Read messages until we get SUCCESS or FAILURE
            response_time = nil
            loop do
              msg = read_message
              case msg
              when Messaging::Record
                # Skip records, we just want to know if the query succeeded
                next
              when Messaging::Success
                response_time = ((Time.now - start_time) * 1000).round(2)
                return { healthy: true, response_time_ms: response_time, details: 'RETURN 1 succeeded' }
              when Messaging::Failure
                return { healthy: false, response_time_ms: nil, details: 'RETURN 1 failed with error' }
              else
                return { healthy: false, response_time_ms: nil, details: 'RETURN 1 unexpected response' }
              end
            end
          else
            { healthy: false, response_time_ms: nil, details: 'RETURN 1 run failed' }
          end
        ensure
          # Reset connection state after health check
          reset!
        end
      end

      # Gets Neo4j server status using SHOW SERVERS query.
      #
      # @return [Array<Hash>] server status information
      def get_neo4j_server_status
        write_message(Messaging::Run.new('SHOW SERVERS', {}, {}), 'SERVER_STATUS')
        response = read_message

        case response
        when Messaging::Success
          servers = []

          # Read records until we get SUCCESS
          loop do
            record_response = read_message
            case record_response
            when Messaging::Record
              # Parse server record - this is a simplified version
              servers << parse_neo4j_server_record(record_response)
            when Messaging::Success
              break
            else
              break
            end
          end

          servers
        else
          []
        end
      ensure
        reset!
      end

      # Gets Memgraph server status using SHOW DATABASES query.
      #
      # @return [Array<Hash>] database status information
      def get_memgraph_server_status
        write_message(Messaging::Run.new('SHOW DATABASES', {}, {}), 'SERVER_STATUS')
        response = read_message

        case response
        when Messaging::Success
          databases = []

          # Read records until we get SUCCESS
          loop do
            record_response = read_message
            case record_response
            when Messaging::Record
              # Parse database record
              databases << parse_memgraph_database_record(record_response)
            when Messaging::Success
              break
            else
              break
            end
          end

          databases
        else
          # Fallback to SHOW DATABASE for single database info
          get_memgraph_current_database
        end
      ensure
        reset!
      end

      # Gets current Memgraph database info using SHOW DATABASE.
      #
      # @return [Array<Hash>] current database information
      def get_memgraph_current_database
        write_message(Messaging::Run.new('SHOW DATABASE', {}, {}), 'CURRENT_DATABASE')
        response = read_message

        case response
        when Messaging::Success
          [{ name: 'current', status: 'active', type: 'memgraph' }]
        else
          []
        end
      ensure
        reset!
      end

      # Parses a Neo4j server record from SHOW SERVERS result.
      #
      # @param record [Messaging::Record] the record message
      # @return [Hash] parsed server information
      def parse_neo4j_server_record(_record)
        # Simplified parsing - in reality this would extract specific fields
        {
          name: 'server',
          address: "#{@host}:#{@port}",
          state: 'Enabled',
          health: 'Available',
          type: 'neo4j'
        }
      end

      # Parses a Memgraph database record from SHOW DATABASES result.
      #
      # @param record [Messaging::Record] the record message
      # @return [Hash] parsed database information
      def parse_memgraph_database_record(_record)
        # Simplified parsing
        {
          name: 'database',
          status: 'active',
          type: 'memgraph'
        }
      end
    end
  end
end
