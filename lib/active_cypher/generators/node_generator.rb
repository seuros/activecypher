# frozen_string_literal: true

require 'rails/generators/active_model'
require 'rails/generators/named_base'

module ActiveCypher
  module Generators
    class NodeGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)
      class_option :suffix, type: :string,
                            desc: 'Suffix for the node class (default: Node)',
                            default: 'Node'

      check_class_collision suffix: 'Node'

      argument :attributes, type: :array,
                            default: [], banner: 'name:type name:type'

      class_option :labels, type: :string,
                            desc: 'Comma‑separated Cypher labels',
                            default: ''

      def create_node_file
        check_runtime_class_collision
        template 'node.rb.erb', File.join('app/graph', class_path, "#{file_name}.rb")
      end

      private

      def check_runtime_class_collision
        suffix = node_suffix
        base = name.camelize
        class_name_with_suffix = base.end_with?(suffix) ? base : "#{base}#{suffix}"
        return unless class_name_with_suffix.safe_constantize

        raise Thor::Error, "Class collision: #{class_name_with_suffix} is already defined"
      end

      def node_suffix
        options[:suffix] || 'Node'
      end

      def class_name
        base = super
        base.end_with?(node_suffix) ? base : "#{base}#{node_suffix}"
      end

      def file_name
        base = super
        suffix = "_#{node_suffix.underscore}"
        base.end_with?(suffix) ? base : "#{base}#{suffix}"
      end

      # helper for ERB
      def labels_list
        lbls = options[:labels].split(',').map(&:strip).reject(&:blank?)
        lbls.empty? ? [class_name.gsub(/#{node_suffix}$/, '')] : lbls
      end
    end
  end
end
