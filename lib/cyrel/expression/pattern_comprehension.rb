# frozen_string_literal: true

require_relative '../expression'
require_relative '../pattern' # Need Path

module Cyrel
  module Expression
    # Represents a Pattern Comprehension in Cypher.
    # Syntax: [ pattern WHERE condition | expression ]
    # Simplified version for now: [ pattern | expression ]
    class PatternComprehension < Base
      attr_reader :pattern, :projection_expression # TODO: Add where_condition

      # @param pattern [Cyrel::Pattern::Path, Cyrel::Pattern::Node, Cyrel::Pattern::Relationship]
      #   The pattern to iterate over.
      # @param projection_expression [Cyrel::Expression::Base, Object]
      #   The expression evaluated for each match of the pattern.
      def initialize(pattern, projection_expression)
        unless pattern.is_a?(Cyrel::Pattern::Path) || pattern.is_a?(Cyrel::Pattern::Node) || pattern.is_a?(Cyrel::Pattern::Relationship)
          raise ArgumentError,
                "Pattern Comprehension pattern must be a Path, Node, or Relationship, got #{pattern.class}"
        end

        @pattern = pattern
        @projection_expression = Expression.coerce(projection_expression)
        # @where_condition = where_condition ? Expression.coerce(where_condition) : nil
      end

      # Renders the pattern comprehension expression.
      # @param query [Cyrel::Query] The query object for rendering pattern and expression.
      # @return [String] The Cypher string fragment.
      def render(query)
        pattern_str = @pattern.render(query)
        # where_str = @where_condition ? " WHERE #{@where_condition.render(query)}" : ""
        projection_str = @projection_expression.render(query)

        "[#{pattern_str} | #{projection_str}]" # Simplified: missing WHERE support
      end
    end

    # Helper function? Might be complex due to pattern definition.
    # def self.comprehend(pattern, projection, where: nil) ... end
  end
end
