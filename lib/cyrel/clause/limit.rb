# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a LIMIT clause in a Cypher query.
    class Limit < Base
      attr_reader :amount

      # Initializes a LIMIT clause.
      # @param amount [Integer, Cyrel::Expression::Base, Object]
      #   The maximum number of results to return. Can be an integer literal or an expression
      #   that evaluates to an integer (typically a parameter).
      def initialize(amount)
        @amount = Expression.coerce(amount)
        # Could add validation here.
      end

      # Renders the LIMIT clause.
      # @param query [Cyrel::Query] The query object for rendering the amount expression.
      # @return [String] The Cypher string fragment for the clause.
      def render(query)
        "LIMIT #{@amount.render(query)}"
      end

      # Merging LIMIT typically replaces the existing value.
      # @param other_limit [Cyrel::Clause::Limit] The other Limit clause.
      def replace!(other_limit)
        @amount = other_limit.amount
        self
      end
    end
  end
end
