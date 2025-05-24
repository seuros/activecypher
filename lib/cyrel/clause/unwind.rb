# frozen_string_literal: true

module Cyrel
  module Clause
    # UNWIND clause for expanding lists into rows
    # Like unpacking a suitcase, but for data and with less wrinkled clothes
    class Unwind < Base
      attr_reader :expression, :variable

      def initialize(expression, variable)
        @expression = expression
        @variable = variable.to_sym
      end

      def render(query)
        cypher_parts = ['UNWIND']

        # Handle the expression
        expr_str = case @expression
                   when Symbol
                     # It's a parameter
                     param_key = query.register_parameter(@expression)
                     "$#{param_key}"
                   when Array
                     # Literal array
                     "[#{@expression.map { |item| render_array_item(item, query) }.join(', ')}]"
                   when Expression::Base
                     # It's already an expression
                     @expression.render(query)
                   else
                     # Try to coerce it
                     Expression.coerce(@expression).render(query)
                   end

        cypher_parts << expr_str
        cypher_parts << 'AS'
        cypher_parts << @variable.to_s

        cypher_parts.join(' ')
      end

      private

      def render_array_item(item, query)
        case item
        when Array
          # Nested array
          "[#{item.map { |v| render_value(v, query) }.join(', ')}]"
        else
          render_value(item, query)
        end
      end

      def render_value(value, query)
        case value
        when String
          "'#{value.gsub("'", "\\\\'")}'"
        when Symbol
          # Symbols in arrays should be rendered as strings
          "'#{value}'"
        when Numeric, TrueClass, FalseClass, NilClass
          value.inspect
        else
          # For more complex values, treat as parameter
          param_key = query.register_parameter(value)
          "$#{param_key}"
        end
      end
    end
  end
end
