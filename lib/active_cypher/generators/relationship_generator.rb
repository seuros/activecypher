# frozen_string_literal: true

require 'rails/generators/active_model'
require 'rails/generators/named_base'

module ActiveCypher
  module Generators
    class RelationshipGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)
      check_class_collision

      argument :attributes, type: :array,
                            default: [], banner: 'name:type name:type'

      class_option :from,  type: :string, required: true,
                           desc: 'Source node class (e.g. UserNode)'
      class_option :to,    type: :string, required: true,
                           desc: 'Target node class (e.g. CompanyNode)'
      class_option :type,  type: :string, default: '',
                           desc: 'Cypher relationship type (defaults to class name)'

      def create_relationship_file
        template 'relationship.rb.erb', File.join('app/graph', class_path, "#{file_name}.rb")
      end

      private

      def relationship_type
        (options[:type].presence || class_name).upcase
      end
    end
  end
end
