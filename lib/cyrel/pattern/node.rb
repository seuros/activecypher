# frozen_string_literal: true

module Cyrel
  module Pattern
    # Represents a node pattern in a Cypher query, e.g., (alias:Label {prop: $param}).
    class Node
      attr_reader :alias_name, :labels, :properties

      # @param alias_name [Symbol, String] The alias for the node.
      # @param labels [Array<Symbol, String>] The labels for the node.
      # @param properties [Hash] The properties to match or set on the node.
      def initialize(alias_name, labels: [], properties: {})
        @alias_name = alias_name.to_sym
        @labels = Array(labels).map(&:to_s) # Ensure labels are strings
        @properties = properties
      end

      # Renders the node pattern part of the Cypher query.
      # @param query [Cyrel::Query] The query object, used for parameter registration.
      # @return [String] The Cypher string fragment for the node pattern.
      def render(query)
        alias_part = @alias_name ? @alias_name.to_s : ''
        # Prepend each label with ':' and join them directly
        labels_part = @labels.empty? ? '' : @labels.map { |l| ":#{l}" }.join('')

        props_part = ''
        if @properties.any?
          prop_strings = @properties.map do |key, value|
            param_key = query.register_parameter(value)
            "#{key}: $#{param_key}"
          end
          # Add space prefix only if alias or labels are present AND properties exist
          prop_prefix = (alias_part.empty? && labels_part.empty?) ? '' : ' '
          props_part = "#{prop_prefix}{#{prop_strings.join(', ')}}"
        end

        # Combine the parts, ensuring correct spacing
        # Combine the parts, ensuring correct spacing
        # Combine the parts, ensuring correct spacing (original logic)
        "(#{alias_part}#{labels_part}#{props_part})"
      end
    end
  end
end
