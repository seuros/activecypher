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

        # Sets up multiple connections for different roles.
        # The `reading` role is now optional and will default to the `writing` role's
        # database key if not explicitly provided.
        #
        # @param mapping [Hash] Role-to-database mapping.
        #   Expected keys:
        #     - :writing [Symbol] (Required) The database key from cypher_databases.yml for write operations.
        #     - :reading [Symbol] (Optional) The database key for read operations. Defaults to the :writing key.
        #     - Other custom roles can also be defined.
        # @return [void]
        def connects_to(mapping)
          # Allow shorthand: pass a symbol or string to use as the writing role
          mapping = { writing: mapping } if mapping.is_a?(Symbol) || mapping.is_a?(String)
          symbolized_mapping = mapping.deep_symbolize_keys

          # Ensure :writing role is present
          raise ArgumentError, 'The :writing role must be defined in connects_to mapping.' unless symbolized_mapping.key?(:writing)

          # Default :reading role to :writing role's db_key if not provided
          symbolized_mapping[:reading] = symbolized_mapping[:writing] unless symbolized_mapping.key?(:reading)

          symbolized_mapping.each do |role, db_key|
            # Allow db_key to be a simple symbol (name of config) or a hash for more complex setups (though less common now)
            spec_name = db_key.is_a?(Hash) ? db_key.values.first : db_key # Basic handling if db_key itself was a hash

            spec = ActiveCypher::CypherConfig.for(spec_name) # May raise KeyError if spec_name not found

            config_for_adapter = spec.dup # Start with the loaded spec

            # If spec contains a URL, parse it using the Registry (via ConnectionUrlResolver)
            if spec[:url]
              resolver = ActiveCypher::ConnectionUrlResolver.new(spec[:url])
              url_config = resolver.to_hash
              raise ArgumentError, "Invalid connection URL: #{spec[:url]}" unless url_config

              # Merge URL config with any other options from the spec, URL takes precedence for core fields
              config_for_adapter = url_config.merge(spec.except(*url_config.keys))
            end

            # Use the Registry to create the adapter for the pool
            # The adapter itself will store its config, the pool just needs to be identified
            # We are creating a pool per unique (role, shard -> db_key)
            # The ConnectionPool will instantiate the adapter using this config_for_adapter
            pool = ActiveCypher::ConnectionPool.new(config_for_adapter)
            connection_handler.set(role.to_sym, :default, pool) # Assuming :default shard for now
          rescue KeyError => e
            raise ActiveCypher::UnknownConnectionError,
                  "connects_to role `#{role}`: database configuration key `#{spec_name.inspect}` not found in cypher_databases.yml – #{e.message}"
          end
          # Store the processed mapping for inspection or other uses if needed
          self.connects_to_mappings = symbolized_mapping
        end
      end
    end
  end
end
