# frozen_string_literal: true

require 'timeout'
require 'async'

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

      # Initialize connection pool components
      @available_connections = []
      @all_connections = []
      @pool_mutex = Mutex.new
      @condition = ConditionVariable.new
      @creation_mutex = Mutex.new
      @retry_count = 0
    end

    # Returns a live adapter from the connection pool.
    # Handles both sync and async contexts seamlessly.
    def connection
      timeout_time = Time.now + @spec[:pool_timeout]

      @pool_mutex.synchronize do
        loop do
          # Try to get an existing available connection
          conn_wrapper = checkout_existing_connection
          if conn_wrapper
            conn_wrapper.mark_in_use!
            return conn_wrapper.adapter  # Return the underlying adapter
          end

          # Try to create a new connection if under limit
          if @all_connections.size < @spec[:pool_size]
            conn_wrapper = create_new_connection_unsafe
            conn_wrapper.mark_in_use!
            return conn_wrapper.adapter  # Return the underlying adapter
          end

          # Pool is full, wait for a connection to become available
          remaining_time = timeout_time - Time.now
          if remaining_time <= 0
            raise ConnectionTimeoutError, "Could not obtain connection within #{@spec[:pool_timeout]} seconds"
          end

          @condition.wait(@pool_mutex, remaining_time)
        end
      end
    rescue => e
      increment_retry_count
      raise e
    end
    alias checkout connection

    # Return a connection to the pool
    # Accepts either the adapter or the wrapper
    def checkin(connection)
      return unless connection

      @pool_mutex.synchronize do
        # Find the wrapper for this adapter
        wrapper = if connection.is_a?(ConnectionWrapper)
          connection
        else
          # Find wrapper by adapter instance
          @all_connections.find { |w| w.adapter == connection }
        end

        if wrapper
          wrapper.mark_not_in_use!
          @available_connections << wrapper unless @available_connections.include?(wrapper)
          @condition.signal
        end
      end
    end

    # Check if the pool has a persistent connection issue
    def troubled?
      @retry_count >= @spec[:max_retries]
    end

    # Explicitly disconnect all connections in the pool
    def disconnect
      @pool_mutex.synchronize do
        @all_connections.each do |conn|
          begin
            conn.disconnect if conn.respond_to?(:disconnect)
          rescue StandardError => e
            puts "Warning: Error disconnecting: #{e.message}" if ENV['DEBUG']
          end
        end
        @available_connections.clear
        @all_connections.clear
      end
      @retry_count = 0
    end

    # Get pool statistics for monitoring
    def size
      @spec[:pool_size]
    end

    def checked_out_connections
      @all_connections.count(&:in_use?)
    end

    def available_connections
      @available_connections.size
    end

    def total_connections
      @all_connections.size
    end

    # Execute a block with a checked-out connection
    def with_connection
      adapter = connection
      begin
        yield adapter
      ensure
        checkin(adapter)
      end
    end

    private

    def increment_retry_count
      @retry_count += 1
    end

    def checkout_existing_connection
      while (conn = @available_connections.pop)
        # Verify the connection is still valid
        if conn.viable?
          return conn
        else
          # Remove invalid connection and try next one
          remove_connection_unsafe(conn)
        end
      end
      nil
    end

    def create_new_connection_unsafe
      # This method should only be called within @pool_mutex.synchronize
      conn = build_connection
      @all_connections << conn
      conn
    end

    def remove_connection_unsafe(connection)
      # This method should only be called within @pool_mutex.synchronize
      @available_connections.delete(connection)
      @all_connections.delete(connection)
      begin
        connection.disconnect if connection.respond_to?(:disconnect)
      rescue StandardError => e
        puts "Warning: Error disconnecting removed connection: #{e.message}" if ENV['DEBUG']
      end
    end

    # Factory method for creating new connections
    def build_connection
      adapter_name = @spec[:adapter]
      raise ArgumentError, 'Missing adapter name in connection specification' unless adapter_name

      adapter_class = ActiveCypher::ConnectionAdapters
                      .const_get("#{adapter_name}_adapter".camelize)

      # Create the underlying adapter
      underlying_adapter = adapter_class.new(@spec)

      # Connect the underlying adapter
      connect_adapter(underlying_adapter)

      # Wrap it for pool management
      wrapper = ConnectionWrapper.new(underlying_adapter, @spec)

      # Reset retry count on successful connection
      @retry_count = 0
      wrapper
    rescue NameError
      raise ActiveCypher::AdapterNotFoundError, "Could not find adapter class for '#{adapter_name}'"
    end

    def connect_adapter(adapter)
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
      rescue StandardError => e
        raise ConnectionError, "Failed to connect: #{e.message}"
      end
    end
  end

  # Wrapper class to provide additional connection pool functionality
  # while maintaining compatibility with existing adapter interface
  class ConnectionWrapper
    extend Forwardable

    # Delegate all adapter methods including class introspection
    def_delegators :@adapter, :execute_cypher, :run, :hydrate_record, :process_records,
                   :prepare_params, :config, :raw_connection, :begin_transaction,
                   :commit_transaction, :rollback_transaction, :convert_access_mode,
                   :class, :is_a?, :kind_of?, :instance_of?, :respond_to_missing?

    # Additional critical methods for adapter functionality
    def_delegators :@adapter, :vendor, :schema_catalog, :reset!, :ping, :version,
                   :database_exists?, :create_database, :database_name

    attr_reader :adapter, :spec, :created_at, :last_used_at

    def initialize(adapter, spec)
      @adapter = adapter
      @spec = spec
      @created_at = Time.now
      @last_used_at = Time.now
      @in_use = false
      @mutex = Mutex.new
    end

    def connect
      @mutex.synchronize do
        @adapter.connect if @adapter.respond_to?(:connect)
        @last_used_at = Time.now
      end
    end

    def disconnect
      @mutex.synchronize do
        @adapter.disconnect if @adapter.respond_to?(:disconnect)
      end
    end

    def reconnect
      @mutex.synchronize do
        @adapter.reconnect if @adapter.respond_to?(:reconnect)
        @last_used_at = Time.now
      end
    end

    def active?
      @adapter.respond_to?(:active?) && @adapter.active?
    end

    # Track connection usage for pool management
    def in_use?
      @in_use
    end

    def mark_in_use!
      @in_use = true
      @last_used_at = Time.now
    end

    def mark_not_in_use!
      @in_use = false
    end

    # Verify connection is still viable
    def viable?
      begin
        active? && (Time.now - @last_used_at) < (@spec[:connection_timeout] || 300)
      rescue StandardError => e
        puts "Warning: Error checking connection viability: #{e.message}" if ENV['DEBUG']
        false
      end
    end

    # Override method_missing to delegate any missing methods to the adapter
    def method_missing(method, *args, **kwargs, &block)
      if @adapter.respond_to?(method)
        @adapter.send(method, *args, **kwargs, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @adapter.respond_to?(method, include_private) || super
    end

    def inspect
      "#<#{self.class}:0x#{object_id.to_s(16)} @adapter=#{@adapter.class} @active=#{active?} @in_use=#{in_use?}>"
    end
  end

  # Custom exceptions for connection pool errors
  class ConnectionPoolError < Error; end
  class ConnectionPoolFullError < ConnectionPoolError; end
end