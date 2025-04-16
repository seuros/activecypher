# frozen_string_literal: true

module ActiveCypher
  module Model
    # Handles connection logic for models, because every ORM needs a way to feel connected.
    # @note All real connection magic is just Ruby sorcery, a dash of forbidden Ruby incantations, and a sprinkle of ActiveSupport witchcraft.
    module ConnectionHandling
      extend ActiveSupport::Concern

      class_methods do
        # Establishes a connection for the model.
        # Because every model deserves a shot at disappointment.
        # @note Under the hood, this is just Ruby sorcery and a little forbidden Ruby wizardry to make your config work.
        def establish_connection(config)
          cfg = config.symbolize_keys

          # Handle both URL-based and traditional config
          if cfg[:url]
            # Use ConnectionUrlResolver for URL-based config
            resolver = ActiveCypher::ConnectionUrlResolver.new(cfg[:url])
            resolved_config = resolver.to_hash

            # Merge any additional config options
            resolved_config = resolved_config.merge(cfg.except(:url)) if resolved_config

            # Bail if URL couldn't be parsed
            raise ArgumentError, "Invalid connection URL: #{cfg[:url]}" unless resolved_config

            # Get adapter name from resolved config
            adapter_name = resolved_config[:adapter]
          else
            # Traditional config with explicit adapter
            adapter_name = cfg[:adapter] or raise ArgumentError, 'Missing :adapter'
            resolved_config = cfg
          end

          path          = "active_cypher/connection_adapters/#{adapter_name}_adapter"
          class_name    = "#{adapter_name}_adapter".camelize

          require path
          adapter_class = ActiveCypher::ConnectionAdapters.const_get(class_name)
          self.connection = adapter_class.new(resolved_config)
          connection.connect
          connection
        rescue LoadError => e
          raise AdapterLoadError, "Could not load ActiveCypher adapter '#{adapter_name}' (#{e.message})"
        end

        # Sets up multiple connections for different roles, because one pool is never enough.
        # @param mapping [Hash] Role-to-database mapping
        # @return [void]
        # Sets up multiple connections for different roles, because one pool is never enough.
        # @param mapping [Hash] Role-to-database mapping
        # @return [void]
        # @note This is where the Ruby gremlins really start dancing—multiple pools, one registry, and a sprinkle of connection witchcraft.
        def connects_to(mapping)
          mapping.deep_symbolize_keys.each do |role, db_key|
            spec = ActiveCypher::CypherConfig.for(db_key) # ← may raise KeyError

            # If spec contains a URL, use ConnectionFactory
            if spec[:url]
              factory = ActiveCypher::ConnectionFactory.new(spec[:url])
              spec = factory.config.merge(spec.except(:url)) if factory.valid?
            end

            pool = ActiveCypher::ConnectionPool.new(spec)
            connection_handler.set(role.to_sym, :default, pool)
          rescue KeyError => e
            raise ActiveCypher::UnknownConnectionError,
                  "connects_to #{role}: #{db_key.inspect} – #{e.message}"
          end
        end
      end
    end
  end
end
