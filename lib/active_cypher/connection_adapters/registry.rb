# frozen_string_literal: true

module ActiveCypher
  module ConnectionAdapters
    # Registry: Because every adapter wants to feel special, and every ORM needs a secret society.
    # This class is the adapter speakeasy—register your adapter, get on the list, and maybe, just maybe,
    # you'll get to connect to a database tonight. Under the hood, it's just a hash, a dash of Ruby mischief,
    # and the occasional existential dread when you realize your adapter isn't registered.
    class Registry
      class << self
        # The sacred scroll of adapters. Not inherited, not shared—just ours.
        def adapters
          @adapters ||= {}
        end

        # Register an adapter class for a specific database type.
        # Because every adapter wants to be chosen, but only a few make the cut.
        # @param adapter_type [String] The adapter type name (e.g., 'neo4j', 'memgraph')
        # @param adapter_class [Class] The adapter class to register
        def register(adapter_type, adapter_class)
          adapters[adapter_type.to_s.downcase] = adapter_class
        end

        # Get all registered adapters (for those who like to peek behind the curtain).
        # @return [Hash] The hash of registered adapters
        def adapters_dup
          adapters.dup
        end

        # Summon an adapter from a connection URL.
        # @param url [String] Connection URL (e.g., "neo4j://user:pass@localhost:7687")
        # @param options [Hash] Additional options for the connection
        # @return [AbstractAdapter] An instance of the appropriate adapter
        def create_from_url(url, options = {})
          resolver = ActiveCypher::ConnectionUrlResolver.new(url)
          config = resolver.to_hash
          return nil unless config

          create_from_config(config, options)
        end

        # Conjure an adapter from a configuration hash.
        # @param config [Hash] Configuration hash with adapter, host, port, etc.
        # @param options [Hash] Additional options for the connection
        # @return [AbstractAdapter] An instance of the appropriate adapter, or a cryptic error if you angered the registry spirits.
        def create_from_config(config, options = {})
          adapter_type = config[:adapter].to_s.downcase
          adapter_class = adapters[adapter_type]
          raise ActiveCypher::ConnectionError, "No adapter registered for '#{adapter_type}'. The registry is silent." unless adapter_class

          full_config = config.merge(options)
          adapter_class.new(full_config)

          # No fallback, just blow up with a cryptic error.
        end

        # Creates a Bolt driver from a connection URL, because sometimes you want to skip the foreplay and go straight to disappointment.
        # @param url [String] Connection URL
        # @param pool_size [Integer] Connection pool size
        # @param options [Hash] Additional options
        # @return [Bolt::Driver] The configured driver, or a ticket to the debugging underworld.
        def create_driver_from_url(url, pool_size: 5, options: {})
          resolver = ActiveCypher::ConnectionUrlResolver.new(url)
          config = resolver.to_hash
          return nil unless config

          adapter = create_from_config(config, options)
          return nil unless adapter

          # Always use 'bolt' scheme for driver creation, regardless of adapter
          uri = "bolt://#{config[:host]}:#{config[:port]}"
          auth_token = {
            scheme: 'basic',
            principal: config[:username],
            credentials: config[:password]
          }
          ActiveCypher::Bolt::Driver.new(
            uri: uri,
            adapter: adapter,
            auth_token: auth_token,
            pool_size: pool_size
          )
        end
      end
    end
  end
end
