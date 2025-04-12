# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a MERGE clause in a Cypher query.
    # Used to find a pattern or create it if it doesn't exist.
    class Merge < Base
      attr_reader :pattern

      # TODO: Add support for ON CREATE SET and ON MATCH SET if needed later.

      # @param pattern [Cyrel::Pattern::Path, Cyrel::Pattern::Node, Cyrel::Pattern::Relationship]
      #   The pattern to merge. Typically a Path or Node.
      def initialize(pattern)
        # Ensure pattern is a valid type for MERGE
        unless pattern.is_a?(Cyrel::Pattern::Path) || pattern.is_a?(Cyrel::Pattern::Node) || pattern.is_a?(Cyrel::Pattern::Relationship)
          raise ArgumentError,
                "MERGE pattern must be a Cyrel::Pattern::Path, Node, or Relationship, got #{pattern.class}"
        end

        @pattern = pattern
      end

      # Renders the MERGE clause.
      # @param query [Cyrel::Query] The query object for rendering the pattern.
      # @return [String] The Cypher string fragment for the clause.
      def render(query)
        pattern_string = @pattern.render(query)
        "MERGE #{pattern_string}"
        # TODO: Append ON CREATE SET / ON MATCH SET rendering when implemented.
      end
    end
  end
end
