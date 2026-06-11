# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a CREATE clause in a Cypher query.
    class Create < Base
      attr_reader :pattern

      # @param pattern [Cyrel::Pattern::Path, Cyrel::Pattern::Node, Cyrel::Pattern::Relationship]
      #   The pattern to create. Typically a Path or Node.
      def initialize(pattern)
        Cyrel::Pattern.assert_pattern!(pattern, 'CREATE')

        # NOTE: Creating relationships between existing nodes requires coordination.
        # The pattern itself should reference existing aliases defined in a preceding MATCH/MERGE.
        # The Query object might need to track defined aliases if validation is needed here.
        @pattern = pattern
      end

      # Renders the CREATE clause.
      # @param query [Cyrel::Query] The query object for rendering the pattern.
      # @return [String] The Cypher string fragment for the clause.
      def render(query)
        pattern_string = @pattern.render(query)
        "CREATE #{pattern_string}"
      end
    end
  end
end
