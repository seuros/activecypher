# frozen_string_literal: true

require 'rails/railtie'
require 'active_cypher/logging'
require 'active_cypher/cypher_config'

module ActiveCypher
  class Railtie < ::Rails::Railtie
    initializer 'active_cypher.logger' do
      ActiveSupport.on_load(:active_cypher) do
        ActiveCypher::Logging.backend = Rails.logger

        # Honour Rails.env level unless the user set AC_LOG_LEVEL
        ActiveCypher::Logging.backend.level = Rails.logger.level unless ENV['AC_LOG_LEVEL']
      end
    end

    initializer 'active_cypher.load_multi_db' do |_app|
      configs = ActiveCypher::CypherConfig.for('*')

      # First, create pools for all configurations
      connection_pools = {}
      configs.each do |name, cfg|
        connection_pools[name.to_sym] = ActiveCypher::ConnectionPool.new(cfg)
      end

      # Register all pools under their own names with the database key
      connection_pools.each do |name, pool|
        # Store the pool with db_key only
        ActiveCypher::Base.connection_handler.set(name, pool)
      end

      # Register default roles (writing, reading)
      # Use primary pool if available, otherwise use the first pool
      default_db_key = :primary
      default_pool = connection_pools[:primary] || connection_pools.values.first
      default_db_key = connection_pools.keys.first unless connection_pools.key?(:primary)

      if default_pool
        # Store the default pool with db_key only
        ActiveCypher::Base.connection_handler.set(default_db_key, default_pool)
      end

      # Find all abstract node base classes with connects_to mappings
      ObjectSpace.each_object(Class) do |klass|
        next unless klass < ActiveCypher::Base
        next unless klass.respond_to?(:abstract_class?) && klass.abstract_class?
        next unless klass.respond_to?(:connects_to_mappings) && klass.connects_to_mappings.present?

        # Register pools for each role in connects_to mapping
        klass.connects_to_mappings.each_value do |conn_name|
          conn_name = conn_name.to_s.to_sym
          pool = connection_pools[conn_name]
          next unless pool

          # Only create a new pool if one doesn't exist for this role and db_key combination
          # Format: set(db_key, role, shard, pool)
          ActiveCypher::Base.connection_handler.set(conn_name, pool) unless ActiveCypher::Base.connection_handler.pool(conn_name)
        end
      end
    end

    generators do
      require 'active_cypher/generators/install_generator'
      require 'active_cypher/generators/node_generator'
      require 'active_cypher/generators/relationship_generator'
    end

    rake_tasks do
      load File.expand_path('../tasks/graphdb_migrate.rake', __dir__)
    end
  end
end
