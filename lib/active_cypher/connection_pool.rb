# frozen_string_literal: true

require 'timeout'

module ActiveCypher
  class ConnectionPool
    attr_reader :spec, :connection_key

    def initialize(spec)
      @spec = spec.symbolize_keys

      # Set defaults for pool configuration
      @spec[:pool_size] ||= ENV.fetch('BOLT_POOL_SIZE', 10).to_i
      @spec[:pool_timeout] ||= ENV.fetch('BOLT_POOL_TIMEOUT', 5).to_i
      @spec[:max_retries] ||= ENV.fetch('BOLT_MAX_RETRIES', 3).to_i

      # Handle URL-based configuration if present
      if @spec[:url] && !@spec.key?(:adapter)
        resolver = ActiveCypher::ConnectionUrlResolver.new(@spec[:url])
        resolved_config = resolver.to_hash

        raise ArgumentError, "Invalid connection URL: #{@spec[:url]}" unless resolved_config

        # Merge the resolved config with any additional options
        @spec = resolved_config.merge(@spec.except(:url))
      end

      @conn_ref = nil # holds the adapter instance
      @creation_mutex = Mutex.new # prevents multiple threads from creating connections simultaneously
      @retry_count = 0
    end

    # Returns a live adapter, initializing it once in a thread‑safe way.
    def connection
      # Fast path — already connected and alive
      conn = @conn_ref
      return conn if conn&.active?

      # Use mutex for the slow path to prevent thundering herd
      @creation_mutex.synchronize do
        # Check again inside the mutex in case another thread created it
        conn = @conn_ref
        return conn if conn&.active?

        # Create a new connection
        new_conn = build_connection
        @conn_ref = new_conn
        return new_conn
      end
    end
    alias checkout connection

    # Check if the pool has a persistent connection issue
    def troubled?
      @retry_count >= @spec[:max_retries]
    end

    # Explicitly close and reset the connection
    def disconnect
      conn = @conn_ref
      return unless conn

      begin
        conn.disconnect
      rescue StandardError => e
        # Log but don't raise to ensure cleanup continues
        puts "Warning: Error disconnecting: #{e.message}" if ENV['DEBUG']
      ensure
        @conn_ref = nil
      end
    end

    private

    def build_connection
      adapter_name = @spec[:adapter]
      raise ArgumentError, 'Missing adapter name in connection specification' unless adapter_name

      adapter_class = ActiveCypher::ConnectionAdapters
                      .const_get("#{adapter_name}_adapter".camelize)

      adapter = adapter_class.new(@spec)

      # Use timeout to avoid hanging during connection
      begin
        Timeout.timeout(@spec[:pool_timeout]) do
          adapter.connect
        end
      rescue Timeout::Error
        begin
          adapter.disconnect
        rescue StandardError
          nil
        end
        raise ConnectionError, "Connection timed out after #{@spec[:pool_timeout]} seconds"
      end

      adapter
    rescue NameError
      raise ActiveCypher::AdapterNotFoundError, "Could not find adapter class for '#{adapter_name}'"
    end
  end
end
