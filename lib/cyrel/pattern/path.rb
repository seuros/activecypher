# frozen_string_literal: true

module Cyrel
  module Pattern
    # Represents a linear path pattern in a Cypher query,
    # consisting of an alternating sequence of Node and Relationship objects.
    class Path
      attr_reader :elements

      # @param elements [Array<Cyrel::Pattern::Node, Cyrel::Pattern::Relationship>]
      #   An array starting with a Node, followed by alternating Relationship and Node objects.
      def initialize(elements)
        validate_elements(elements)
        @elements = elements
      end

      # Renders the path pattern part of the Cypher query.
      # @param query [Cyrel::Query] The query object, used for parameter registration.
      # @return [String] The Cypher string fragment for the path pattern.
      def render(query)
        @elements.map { |element| element.render(query) }.join
      end

      private

      # Validates the structure of the elements array.
      def validate_elements(elements)
        raise ArgumentError, 'Path elements must be a non-empty array.' unless elements.is_a?(Array) && elements.any?
        raise ArgumentError, 'Path must start with a Node.' unless elements.first.is_a?(Cyrel::Pattern::Node)

        elements.each_with_index do |element, index|
          expected_class = (index.even? ? Cyrel::Pattern::Node : Cyrel::Pattern::Relationship)
          unless element.is_a?(expected_class)
            raise ArgumentError,
                  "Invalid element sequence at index #{index}. Expected #{expected_class}, got #{element.class}."
          end
        end
      end
    end
  end
end
