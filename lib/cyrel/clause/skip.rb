# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a SKIP clause in a Cypher query.
    class Skip < Base
      attr_reader :amount

      # Initializes a SKIP clause.
      # @param amount [Integer, Cyrel::Expression::Base, Object]
      #   The number of results to skip. Can be an integer literal or an expression
      #   that evaluates to an integer (typically a parameter).
      def initialize(amount)
        @amount = Expression.coerce(amount)
        # Could add validation here to ensure the expression likely returns an integer,
        # but Cypher itself will handle runtime errors.
      end

      # Renders the SKIP clause.
      # @param query [Cyrel::Query] The query object for rendering the amount expression.
      # @return [String] The Cypher string fragment for the clause.
      def render(query)
        "SKIP #{@amount.render(query)}"
      end

      # Merging SKIP typically replaces the existing value.
      # @param other_skip [Cyrel::Clause::Skip] The other Skip clause.
      def replace!(other_skip)
        @amount = other_skip.amount
        self
      end
    end
  end
end
