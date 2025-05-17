# frozen_string_literal: true

require 'uri'
require 'async'
require 'async/pool'

module ActiveCypher
  module Bolt
    # @!parse
    #   # The Bolt Driver manages connection pooling and session creation for Bolt protocol.
    #   # Because apparently every ORM needs to reinvent connection pooling, but with more existential dread.
    class Driver
      DEFAULT_POOL_SIZE = ENV.fetch('BOLT_POOL_SIZE', 10).to_i

      # Initializes the driver, because you can't spell "abstraction" without "action".
      #
      # @param uri [String] The Bolt URI
      # @param adapter [Object] The adapter instance
      # @param auth_token [Hash] Authentication token
      # @param pool_size [Integer] Connection pool size
      # @param secure [Boolean] Use SSL (default: false)
      # @param verify_cert [Boolean] Verify SSL certificate (default: true)
      def initialize(uri:, adapter:, auth_token:, pool_size: DEFAULT_POOL_SIZE, secure: false, verify_cert: true)
        @uri = URI(uri)

        @adapter       = adapter
        @auth          = auth_token
        @secure        = secure
        @verify_cert   = verify_cert

        # Create a connection pool with the specified size
        # Because one connection is never enough for true disappointment.
        @pool = Async::Pool::Controller.wrap(
          limit: pool_size
        ) { build_connection }
      end

      # Yields a Session. Works inside or outside an Async reactor.
      # Because sometimes you want async, and sometimes you just want to feel something.
      #
      # @yieldparam session [Bolt::Session] The session to use
      # @return [Object] The result of the block
      def with_session(**kw)
        if Async::Task.current?
          # We're already in an Async context, use the pool directly
          @pool.acquire do |conn|
            # Check if connection is viable before using it
            unless conn.viable?
              # Create a fresh connection, because hope springs eternal
              begin
                conn.close
              rescue StandardError
                nil
              end
              conn = build_connection
            end

            yield Bolt::Session.new(conn, **kw)
          end
        else
          # We're not in an Async context, create one and wait
          Async do
            @pool.acquire do |conn|
              # Check if connection is viable before using it
              unless conn.viable?
                # Create a fresh connection, because why not
                begin
                  conn.close
                rescue StandardError
                  nil
                end
                conn = build_connection
              end

              yield Bolt::Session.new(conn, **kw)
            end
          end.wait
        end
      rescue Async::TimeoutError => e
        raise ActiveCypher::ConnectionError, "Connection pool timeout: #{e.message}"
      rescue StandardError => e
        raise ActiveCypher::ConnectionError, "Connection error: #{e.message}"
      end

      # Checks if the database is alive, or just faking it for your benefit.
      #
      # @return [Boolean]
      def verify_connectivity
        with_session { |s| s.run('RETURN 1') }
        true
      rescue StandardError
        false
      end

      # Closes the connection pool. Because sometimes you just need to let go.
      def close
        @pool.close
      rescue StandardError => e
        # Log but don't raise to ensure we don't prevent cleanup
        puts "Warning: Error while closing connection pool: #{e.message}" if ENV['DEBUG']
      end

      private

      # Builds a new connection, because the old one just wasn't good enough.
      #
      # @return [Connection]
      def build_connection
        connection = Connection.new(
          @uri.host,
          @uri.port || 7687,
          @adapter,
          auth_token: @auth,
          timeout_seconds: 15,
          secure: @secure,
          verify_cert: @verify_cert
        )

        begin
          connection.connect
        rescue StandardError => e
          begin
            connection.close
          rescue StandardError
            nil
          end
          raise e
        end

        connection
      end
    end
  end
end
