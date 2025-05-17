# frozen_string_literal: true

require 'rails/railtie'
require 'active_cypher/railtie'
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
      configs.each do |name, cfg|
        pool = ActiveCypher::ConnectionPool.new(cfg)
        ActiveCypher::Base.connection_handler.set(name.to_sym, :default, pool)
      end
    end

    generators do
      require 'active_cypher/generators/install_generator'
      require 'active_cypher/generators/node_generator'
      require 'active_cypher/generators/relationship_generator'
    end
  end
end
