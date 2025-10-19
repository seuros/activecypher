# frozen_string_literal: true

module ActiveCypher
  module Model
    # Handles connection logic for models, because even graph nodes need to feel emotionally wired.
    # @note Under the hood: it's just Ruby metaprogramming, config keys, and a dash of ActiveSupport pixie dust.
    module ConnectionHandling
      extend ActiveSupport::Concern

      class_methods do
        # Sets up database connections for different roles (e.g., writing, reading, analytics).
        #
        # Supports shorthand (just pass a symbol/string for writing role).
        # If :reading isn’t provided, it defaults to the same DB as :writing. Because DRY is still cool.
        #
        # @param mapping [Hash] A role-to-database mapping. Keys are roles, values are DB keys or specs.
        #   Example:
        #     connects_to writing: :primary, reading: :replica
        # @return [void]
        def connects_to(mapping)
          mapping = { writing: mapping } if mapping.is_a?(Symbol) || mapping.is_a?(String)
          symbolized_mapping = mapping.deep_symbolize_keys

          raise ArgumentError, 'The :writing role must be defined in connects_to mapping.' unless symbolized_mapping.key?(:writing)

          # If you're lazy and don't specify :reading, it defaults to :writing. You're welcome.
          symbolized_mapping[:reading] ||= symbolized_mapping[:writing]

          processed_specs = {}

          symbolized_mapping.each do |role, db_key|
            spec_names_for(db_key).each do |spec_name|
              spec_key = spec_name.respond_to?(:to_sym) ? spec_name.to_sym : spec_name

              next if processed_specs.key?(spec_key)

              processed_specs[spec_key] = true

              # Reuse existing pools rather than instantiating duplicates
              next if connection_handler.pool(spec_key)

              begin
                spec = ActiveCypher::CypherConfig.for(spec_key) # Boom. Pulls your DB config.
              rescue KeyError => e
                raise ActiveCypher::UnknownConnectionError,
                      "connects_to role `#{role}`: database configuration key `#{spec_name.inspect}` not found in cypher_databases.yml – #{e.message}"
              end

              config_for_adapter = spec.dup

              # If the spec has a URL, parse it and let it override the boring YAML values.
              if spec[:url]
                resolver = ActiveCypher::ConnectionUrlResolver.new(spec[:url])
                url_config = resolver.to_hash
                raise ArgumentError, "Invalid connection URL: #{spec[:url]}" unless url_config

                config_for_adapter = url_config.merge(spec.except(*url_config.keys))
              end

              # Create a unique connection pool for this role/config combo.
              pool = ActiveCypher::ConnectionPool.new(config_for_adapter)

              # Register the pool under this spec name.
              connection_handler.set(spec_key, pool)
            end
          end

          # Save the mapping for later — introspection, debugging, blaming, etc.
          self.connects_to_mappings = symbolized_mapping
        end

        private

        def spec_names_for(db_key)
          values = db_key.is_a?(Hash) ? db_key.values : db_key
          Array(values).flatten.compact
        end
      end
    end
  end
end
