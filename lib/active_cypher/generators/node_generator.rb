# frozen_string_literal: true

require 'rails/generators/active_model'
require 'rails/generators/named_base'

module ActiveCypher
  module Generators
    class NodeGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)
      check_class_collision

      argument :attributes, type: :array,
                            default: [], banner: 'name:type name:type'

      class_option :labels, type: :string,
                            desc: 'Comma‑separated Cypher labels',
                            default: ''

      def create_node_file
        template 'node.rb.erb', File.join('app/graph', class_path, "#{file_name}.rb")
      end

      private

      # helper for ERB
      def labels_list
        lbls = options[:labels].split(',').map(&:strip).reject(&:blank?)
        lbls.empty? ? [class_name.gsub(/Node$/, '')] : lbls
      end
    end
  end
end
