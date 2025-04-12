# frozen_string_literal: true

require_relative '../expression'

module Cyrel
  module Expression
    # Represents a CASE expression in Cypher.
    # Supports the generic form: CASE WHEN c1 THEN r1 WHEN c2 THEN r2 ... ELSE d END
    # TODO: Support simple form: CASE input WHEN v1 THEN r1 ... ELSE d END
    class Case < Base
      attr_reader :whens, :else_result

      # @param whens [Array<Array>] An array of [condition, result] pairs.
      #   Condition and result objects will be coerced to Expressions.
      # @param else_result [Object, nil] The value for the ELSE branch (coerced). Optional.
      def initialize(whens: [], else_result: nil)
        unless whens.is_a?(Array) && whens.all? { |pair| pair.is_a?(Array) && pair.length == 2 }
          raise ArgumentError, "CASE 'whens' must be an array of [condition, result] pairs."
        end

        @whens = whens.map do |condition, result|
          [Expression.coerce(condition), Expression.coerce(result)]
        end
        @else_result = else_result ? Expression.coerce(else_result) : nil
        raise ArgumentError, 'CASE expression requires at least one WHEN clause.' if @whens.empty?
      end

      # Renders the CASE expression.
      # @param query [Cyrel::Query] The query object for rendering conditions/results.
      # @return [String] The Cypher string fragment.
      def render(query)
        parts = ['CASE']
        @whens.each do |condition, result|
          parts << "WHEN #{condition.render(query)} THEN #{result.render(query)}"
        end
        parts << "ELSE #{@else_result.render(query)}" if @else_result
        parts << 'END'
        parts.join(' ')
      end
    end

    # Helper function? Might be clearer to instantiate directly.
    # def self.case(whens: [], else_result: nil) ... end
  end
end
