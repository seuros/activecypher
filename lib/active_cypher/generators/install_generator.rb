# frozen_string_literal: true

require 'rails/generators/base'

module ActiveCypher
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc 'Creates cypher_databases.yml and an initializer for ActiveCypher'

      source_root File.expand_path('templates', __dir__)

      def copy_configuration
        template 'cypher_databases.yml', 'config/cypher_databases.yml'
      end

      def copy_base_classes
        empty_directory 'app/graph'
        template 'application_graph_node.rb',         'app/graph/application_graph_node.rb'
        template 'application_graph_relationship.rb', 'app/graph/application_graph_relationship.rb'
      end
    end
  end
end
