# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a WHERE clause in a Cypher query.
    class Where < Base
      attr_reader :conditions

      # @param conditions [Array<Cyrel::Expression::Base, Object>, Cyrel::Expression::Base, Object]
      #   One or more conditions. Non-Expression objects will be coerced.
      def initialize(*conditions)
        @conditions = conditions.flatten.map { |cond| Expression.coerce(cond) }
      end

      # Renders the WHERE clause.
      # Combines multiple conditions using AND.
      # @param query [Cyrel::Query] The query object for rendering conditions.
      # @return [String, nil] The Cypher string fragment, or nil if no conditions exist.
      def render(query)
        return nil if @conditions.empty?

        # Combine conditions with AND if there are multiple
        combined_condition = if @conditions.length == 1
                               @conditions.first
                             else
                               # Build a balanced AND tree for potentially better readability/performance?
                               # For now, simple left-associative AND is fine.
                               @conditions.reduce { |memo, cond| Expression::Logical.new(memo, :AND, cond) }
                             end

        "WHERE #{combined_condition.render(query)}"
      end

      # Merges conditions from another Where clause using AND.
      # @param other_where [Cyrel::Clause::Where] The other Where clause to merge.
      def merge!(other_where)
        @conditions.concat(other_where.conditions)
        self
      end
    end
  end
end
