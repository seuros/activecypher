# frozen_string_literal: true

module Cyrel
  module Expression
    # Represents an aliased expression (e.g., count(n) AS count_n).
    class Alias < Base
      attr_reader :expression, :alias_name

      # @param expression [Cyrel::Expression::Base] The expression being aliased.
      # @param alias_name [Symbol, String] The alias to assign.
      def initialize(expression, alias_name)
        raise ArgumentError, 'Expression must be a Cyrel::Expression::Base' unless expression.is_a?(Base)

        @expression = expression
        @alias_name = alias_name.to_sym
      end

      # Renders the aliased expression.
      # @param query [Cyrel::Query] The query object for rendering the base expression.
      # @return [String] The Cypher string fragment (e.g., "count(n) AS count_n").
      def render(query)
        rendered_expr = @expression.render(query)
        "#{rendered_expr} AS #{@alias_name}"
      end
    end
  end
end
