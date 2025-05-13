# frozen_string_literal: true

require 'rails/generators/active_model'
require 'rails/generators/named_base'

module ActiveCypher
  module Generators
    class RelationshipGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)
      class_option :suffix, type: :string,
                            desc: 'Suffix for the relationship class (default: Rel)',
                            default: 'Rel'

      argument :attributes, type: :array,
                            default: [], banner: 'name:type name:type'

      class_option :from,  type: :string, required: true,
                           desc: 'Source node class (e.g. UserNode)'
      class_option :to,    type: :string, required: true,
                           desc: 'Target node class (e.g. CompanyNode)'
      class_option :type,  type: :string, default: '',
                           desc: 'Cypher relationship type (defaults to class name)'

      def create_relationship_file
        check_runtime_class_collision
        template 'relationship.rb.erb', File.join('app/graph', class_path, "#{file_name}.rb")
      end

      private

      def relationship_suffix
        options[:suffix] || 'Rel'
      end

      def class_name
        base = super
        base.end_with?(relationship_suffix) ? base : "#{base}#{relationship_suffix}"
      end

      def file_name
        base = super
        suffix = "_#{relationship_suffix.underscore}"
        base.end_with?(suffix) ? base : "#{base}#{suffix}"
      end



      def check_runtime_class_collision
        suffix = relationship_suffix
        base = name.camelize
        class_name_with_suffix = base.end_with?(suffix) ? base : "#{base}#{suffix}"
        if Object.const_defined?(class_name_with_suffix)
          raise Thor::Error, "Class collision: #{class_name_with_suffix} is already defined"
        end
      end

      def relationship_type
        (options[:type].presence || class_name).upcase
      end
    end
  end
end
