# frozen_string_literal: true

module Cyrel
  module Expression
    # Represents a comparison operation (e.g., =, <>, <, >, <=, >=, =~, IN, STARTS WITH, etc.).
    class Comparison < Base
      attr_reader :left, :operator, :right

      # Mapping from Ruby-friendly symbols to Cypher operators
      OPERATOR_MAP = {
        :"=" => '=',
        :"==" => '=', # Allow Ruby style equality check
        :"!=" => '<>',
        :"<>" => '<>', # Allow SQL style inequality
        :< => '<',
        :<= => '<=',
        :> => '>',
        :>= => '>=',
        :"=~" => '=~', # Regex
        :IN => 'IN',
        :"STARTS WITH" => 'STARTS WITH',
        :"ENDS WITH" => 'ENDS WITH',
        :CONTAINS => 'CONTAINS',
        :"IS NULL" => 'IS NULL',
        :"IS NOT NULL" => 'IS NOT NULL'
        # Add other Cypher comparison operators as needed
      }.freeze

      # @param left [Cyrel::Expression::Base, Object] The left operand.
      # @param operator [Symbol, String] The comparison operator (e.g., :>, :'=', :IN).
      # @param right [Cyrel::Expression::Base, Object, nil] The right operand (nil for unary ops like IS NULL).
      def initialize(left, operator, right = nil)
        @left = Expression.coerce(left)
        @operator_sym = operator.to_sym
        @cypher_operator = OPERATOR_MAP[@operator_sym] || operator.to_s.upcase # Fallback for unmapped/custom
        raise ArgumentError, "Unknown comparison operator: #{operator}" unless @cypher_operator

        # Handle unary operators like IS NULL / IS NOT NULL
        @right = if right.nil? && (@operator_sym == :"IS NULL" || @operator_sym == :"IS NOT NULL")
                   nil
                 else
                   Expression.coerce(right)
                 end
      end

      # Renders the comparison expression.
      # @param query [Cyrel::Query] The query object for rendering operands.
      # @return [String] The Cypher string fragment (e.g., "(n.age > $p1)").
      def render(query)
        left_rendered = @left.render(query)
        if @right.nil? # Unary operator
          "(#{left_rendered} #{@cypher_operator})"
        else
          right_rendered = @right.render(query)
          "(#{left_rendered} #{@cypher_operator} #{right_rendered})"
        end
      end
    end
  end
end
