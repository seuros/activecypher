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

      # One connection per thread: Bolt is a stateful, ordered protocol, so
      # sharing a socket across threads corrupts the stream. @connections
      # exists only so disconnect can close them all; the thread-local is
      # what the hot path reads.
      @connections = {}
      @creation_mutex = Mutex.new
    end

    # Returns a live adapter belonging to the calling thread.
    def connection
      conn = Thread.current[thread_key]
      return conn if conn&.active?

      # Built outside the mutex: connecting does network IO.
      new_conn = build_connection
      Thread.current[thread_key] = new_conn

      # Reap dead threads' connections, or each short-lived thread leaks a
      # socket the server counts against max_connections.
      orphaned = @creation_mutex.synchronize do
        dead = @connections.reject { |t, _| t.alive? }
        dead.each_key { |t| @connections.delete(t) }
        @connections[Thread.current] = new_conn
        dead.values
      end

      # Closed outside the mutex: disconnecting does IO too.
      orphaned.each do |conn|
        conn.disconnect
      rescue StandardError => e
        puts "Warning: Error disconnecting orphaned connection: #{e.message}" if ENV['DEBUG']
      end

      new_conn
    end
    alias checkout connection

    # Check if the pool has a persistent connection issue
    def troubled?
      @retry_count >= @spec[:max_retries]
    end

    # Explicitly close every connection this pool handed out.
    def disconnect
      conns = @creation_mutex.synchronize do
        taken = @connections.values
        @connections.clear
        taken
      end

      conns.each do |conn|
        conn.disconnect
      rescue StandardError => e
        # Log but don't raise to ensure cleanup continues
        puts "Warning: Error disconnecting: #{e.message}" if ENV['DEBUG']
      end

      Thread.current[thread_key] = nil
    end

    private

    # Namespaced per pool instance so multiple databases don't share.
    def thread_key
      @thread_key ||= :"active_cypher_connection_#{object_id}"
    end

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
        rescue StandardError => e
          puts "Warning: Error disconnecting during timeout cleanup: #{e.message}" if ENV['DEBUG']
        end
        raise ConnectionError, "Connection timed out after #{@spec[:pool_timeout]} seconds"
      end

      adapter
    rescue NameError
      raise ActiveCypher::AdapterNotFoundError, "Could not find adapter class for '#{adapter_name}'"
    end
  end
end
