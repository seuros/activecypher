# frozen_string_literal: true

module Cyrel
  module Expression
    # Represents a binary arithmetic operation (e.g., +, -, *, /, %, ^).
    class Operator < Base
      attr_reader :left, :operator, :right

      # @param left [Cyrel::Expression::Base, Object] The left operand.
      # @param operator [Symbol] The arithmetic operator symbol (e.g., :+, :*).
      # @param right [Cyrel::Expression::Base, Object] The right operand.
      def initialize(left, operator, right)
        @left = Expression.coerce(left) # Ensure operands are Expression objects
        @operator = operator
        @right = Expression.coerce(right)
      end

      # Renders the operator expression.
      # @param query [Cyrel::Query] The query object for rendering operands.
      # @return [String] The Cypher string fragment (e.g., "(n.age + $p1)").
      def render(query)
        # Parentheses ensure correct precedence
        "(#{@left.render(query)} #{@operator} #{@right.render(query)})"
      end
    end
  end
end
