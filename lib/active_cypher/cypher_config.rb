# frozen_string_literal: true

# lib/active_cypher/cypher_config.rb
require 'active_support'

module ActiveCypher
  module CypherConfig
    #
    # Read config/cypher_databases.yml the Rails‑native way and then
    # pick a *named connection* (default :primary).
    #
    # Works **outside** Rails too by falling back to ActiveSupport::ConfigurationFile.
    #
    def self.for(name = :primary, env: nil, path: nil)
      env  ||= defined?(Rails) ? Rails.env : ENV.fetch('CY_ENV', 'development')
      file   = Pathname.new(path || default_path)

      # Handle missing config file gracefully
      unless file.exist?
        # If requesting all configs, return empty hash
        return {}.with_indifferent_access if name.to_s == '*'
        # If silent missing is set, return nil for specific connection
        return nil if ENV['ACTIVE_CYPHER_SILENT_MISSING'] == 'true'

        # Otherwise, raise a descriptive error
        raise "Could not load ActiveCypher configuration. No such file - #{file}. " \
              "Please run 'rails generate active_cypher:install' to create the configuration file."
      end

      ## ------------------------------------------------------------
      ## 1. Parse YAML using the same algorithm Rails::Application#config_for
      ##    uses (shared‑section merge, ERB, symbolize_keys, etc.)
      ## ------------------------------------------------------------
      merged =
        if defined?(Rails::Application)
          # Leverage the very method you pasted:
          Rails.application.config_for(file, env: env).deep_dup
        else
          # Stand‑alone Ruby script: replicate the merge rules.
          raw     = ActiveSupport::ConfigurationFile.parse(file).deep_symbolize_keys
          config  = raw[env.to_sym] || {}
          shared  = raw[:shared]    || {}
          shared.deep_merge(config)
        end

      return merged.with_indifferent_access if name.to_s == '*'

      merged.fetch(name.to_sym) do
        raise KeyError,
              "No '#{name}' connection in #{env} section of #{file}"
      end.with_indifferent_access
    end

    def self.default_path
      if defined?(Rails)
        Rails.root.join('config', 'cypher_databases.yml')
      else
        File.join(Dir.pwd, 'config', 'cypher_databases.yml')
      end
    end
  end
end
