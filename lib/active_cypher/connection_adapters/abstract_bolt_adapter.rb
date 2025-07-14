# frozen_string_literal: true

require 'uri'
require 'async'

module ActiveCypher
  module ConnectionAdapters
    # Abstract adapter for Bolt-based graph databases.
    # Concrete subclasses must provide protocol_handler_class, validate_connection, and execute_cypher.
    # It's like ActiveRecord::ConnectionAdapter, but for weirdos like me who use graph databases.
    class AbstractBoltAdapter < AbstractAdapter
      include Instrumentation
      attr_reader :connection

      # Returns the raw Bolt connection object
      # This is useful for accessing low-level connection methods like
      # read_transaction, write_transaction, async_read_transaction, etc.
      def raw_connection
        @connection
      end

      # Establish a connection if not already active.
      # This includes auth token prep, URI parsing, and quiet suffering.
      def connect
        return true if active?

        instrument_connection(:connect, config) do
          # Determine host and port from config
          host, port = if config[:uri]
                         # Legacy URI format
                         uri = URI(config[:uri])
                         [uri.host, uri.port || 7687]
                       else
                         # New URL format via ConnectionUrlResolver
                         [config[:host] || 'localhost', config[:port] || 7687]
                       end

          # Prepare auth token
          auth = if config[:username]
                   { scheme: 'basic', principal: config[:username], credentials: config[:password] }
                 else
                   { scheme: 'none' }
                 end

          # Get SSL connection params
          ssl_params = if config[:url]
                         resolver = ActiveCypher::ConnectionUrlResolver.new(config[:url])
                         resolver.ssl_connection_params
                       else
                         {
                           secure: config[:ssl] ? true : false,
                           verify_cert: config[:ssc] ? false : true
                         }
                       end

          @connection = Bolt::Connection.new(
            host, port, self,
            auth_token: auth,
            timeout_seconds: config.fetch(:timeout, 15),
            **ssl_params
          )
          @connection.connect
          validate_connection
        end
      end

      # Connection health check. If this returns false, you're probably in trouble.
      def active? = @connection&.connected?
      alias connected? active?

      # Clean disconnection. Resets the internal state.
      def disconnect
        instrument_connection(:disconnect) do
          @connection&.close
          @connection = nil
          true
        end
      end

      # Runs a Cypher query via Bolt session.
      # Automatically handles connect, logs query, cleans up session. Very adult.
      def run(cypher, params = {}, context: 'Query', db: nil, access_mode: :write)
        connect
        logger.debug { "[#{context}] #{cypher} #{params.inspect}" }

        instrument_query(cypher, params, context: context, metadata: { db: db, access_mode: access_mode }) do
          session = Bolt::Session.new(connection, database: db)
          result  = session.run(cypher, prepare_params(params), mode: access_mode)
          rows    = result.respond_to?(:to_a) ? result.to_a : result
          session.close
          rows
        end
      end

      # Convert access mode to database-specific format
      def convert_access_mode(mode)
        mode.to_s # Default implementation
      end

      # Prepare transaction metadata with database-specific attributes
      def prepare_tx_metadata(metadata, _db, _access_mode)
        metadata # Default implementation
      end

      # Create a protocol handler for the connection
      def create_protocol_handler(connection)
        protocol_handler_class.new(connection)
        # Return handler for connection to store
      end

      # Reset the connection state by sending a RESET message.
      # This clears any pending work and returns the connection to a clean state.
      # Useful for error recovery or connection pooling.
      #
      # @return [Boolean] true if reset succeeded, false otherwise
      def reset!
        return false unless active?

        instrument_connection(:reset, config) do
          # Wrap in async to handle the connection reset properly
          result = nil
          error = nil

          Async do
            begin
              # Try to execute a simple query first
              session = Bolt::Session.new(@connection)
              session.run('RETURN 1 AS check', {})
              session.close
              result = true
            rescue StandardError => e
              # Query failed, need to reset the connection
              logger.debug { "Connection needs reset: #{e.message}" }

              # Send RESET message directly
              begin
                @connection.write_message(Bolt::Messaging::Reset.new)
                response = @connection.read_message
                result = response.is_a?(Bolt::Messaging::Success)
                logger.debug { "Reset response: #{response.class}" }
              rescue StandardError => reset_error
                logger.error { "Reset failed: #{reset_error.message}" }
                result = false
              end
            end
          rescue StandardError => e
            error = e
          end.wait

          raise error if error

          result
        end
      rescue StandardError => e
        # This is madness!
        logger.error { "Failed to reset connection: #{e.message}" }
        false
      end

      protected

      # These must be defined by subclasses. If you don't override them,
      # you will be publicly shamed by a NotImplementedError.
      def protocol_handler_class = raise(NotImplementedError)
      def validate_connection = raise(NotImplementedError)
      def execute_cypher(*) = raise(NotImplementedError, "#{self.class} must implement #execute_cypher")

      private

      # ------------------------------------------------------------------
      # DANGER‑ZONE ‑‑ full‑graph eraser
      #
      # 🔥  Use *only* when you're absolutely certain, or when you need
      #     a dramatic way to prove you're "senior‑material."  (Nothing
      #     says "promotion potential" like nuking the staging graph in
      #     front of the team, right?)
      #
      # Call it with:
      #   adapter.send(:wipe_database, confirm: "yes, really")
      #
      # Options:
      #   :confirm => string   # mandatory safety latch
      #   :batch   => integer  # optional batch size for huge graphs
      #
      # Returns true on success.
      # ------------------------------------------------------------------
      def wipe_database(confirm:, batch: nil)
        raise 'Refusing to wipe without explicit confirmation' unless confirm == 'yes, really'

        if batch
          # Manual batch wipe in case of ginormous graphs.
          loop do
            deleted = execute_cypher(<<~CYPHER, {}, 'Batch‑Delete')
              CALL {
                MATCH ()-[r]-()
                WITH r LIMIT #{batch}
                DELETE r
                RETURN count(r) AS rels
              }
              CALL {
                MATCH (n)
                WITH n LIMIT #{batch}
                DELETE n
                RETURN count(n) AS nodes
              }
              RETURN rels + nodes AS total
            CYPHER
            break if deleted.first[:total].zero?
          end
        else
          # Regular wipe: burn it all.
          execute_cypher('MATCH (n) DETACH DELETE n', {}, 'WipeDB')
        end
        true
      end

      # ------------------------------------------------------------------
      # Converts a Bolt‑encoded Node into a simple Ruby hash.
      # Because we just want the props, not a dissertation on labels.
      # ------------------------------------------------------------------
      def process_node(bolt_array)
        return bolt_array unless bolt_array.is_a?(Array) && bolt_array.first == 78

        _id, _labels, props = bolt_array[1] # we only care about the props
        props
      end
    end

    # ------------------------------------------------------------------
    # AbstractProtocolHandler
    # Handles low‑level connection protocol things like version parsing
    # and resetting the session state. It's like a janitor for Bolt.
    # ------------------------------------------------------------------
    class AbstractProtocolHandler
      attr_reader :connection, :server_version

      def initialize(connection)
        @connection      = connection
        @server_version  = extract_version(connection.server_agent.to_s)
      end

      # Extract the server version string from the agent header.
      # Subclass this if you want to pretend you're compatible.
      def extract_version(_agent) = 'unknown'

      # Sends a Bolt RESET to clear the server's mental state.
      # Great for when you've made a mess and don't want to talk about it.
      def reset!
        connection.write_message(Bolt::Messaging::Reset.new)
        msg = connection.read_message
        msg.is_a?(Bolt::Messaging::Success)
      rescue StandardError
        false
      end
    end
  end
end
