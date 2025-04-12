# frozen_string_literal: true

module Cyrel
  module Expression
    # Represents a logical operation (AND, OR, XOR, NOT).
    class Logical < Base
      attr_reader :left, :operator, :right

      # @param left [Cyrel::Expression::Base, Object] The left operand (or the single operand for NOT).
      # @param operator [Symbol] The logical operator symbol (:AND, :OR, :XOR, :NOT).
      # @param right [Cyrel::Expression::Base, Object, nil] The right operand (nil for NOT).
      def initialize(left, operator, right = nil)
        @operator = operator.to_s.upcase.to_sym # Ensure uppercase symbol
        raise ArgumentError, "Invalid logical operator: #{@operator}" unless %i[AND OR XOR NOT].include?(@operator)

        @left = Expression.coerce(left)
        @right = @operator == :NOT ? nil : Expression.coerce(right)

        raise ArgumentError, "Operator #{@operator} requires two operands." if @operator != :NOT && @right.nil?
        return unless @operator == :NOT && !right.nil?

        raise ArgumentError, 'Operator NOT requires only one operand.'
      end

      # Renders the logical expression.
      # @param query [Cyrel::Query] The query object for rendering operands.
      # @return [String] The Cypher string fragment (e.g., "((n.age > $p1) AND (n.status = $p2))").
      def render(query)
        if @operator == :NOT
          "(#{@operator} #{@left.render(query)})"
        else
          # Parentheses ensure correct precedence
          "(#{@left.render(query)} #{@operator} #{@right.render(query)})"
        end
      end
    end
  end
end
