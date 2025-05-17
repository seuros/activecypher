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

          # Use the Registry to create the adapter
          self.connection = ActiveCypher::ConnectionAdapters::Registry.create_from_config(resolved_config)
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

            # If spec contains a URL, parse it using the Registry (via ConnectionUrlResolver)
            if spec[:url]
              resolver = ActiveCypher::ConnectionUrlResolver.new(spec[:url])
              url_config = resolver.to_hash
              raise ArgumentError, "Invalid connection URL: #{spec[:url]}" unless url_config

              spec = url_config.merge(spec.except(:url))
            end

            # Use the Registry to create the adapter for the pool
            adapter = ActiveCypher::ConnectionAdapters::Registry.create_from_config(spec)
            pool = ActiveCypher::ConnectionPool.new(adapter.config)
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
