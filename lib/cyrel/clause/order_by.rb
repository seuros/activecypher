# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents an ORDER BY clause in a Cypher query.
    class OrderBy < Base
      attr_reader :order_items

      # Initializes an ORDER BY clause.
      # @param order_items [Array<Array>]
      #   An array of arrays, where each inner array contains:
      #   [expression, direction]
      #   - expression: The expression to order by (coerced).
      #   - direction: :asc or :desc (Symbol or String).
      #   e.g., [[Cyrel.prop(:n, :age), :desc], ["name", :asc]]
      def initialize(*order_items)
        @order_items = process_items(order_items) # Process the array of pairs directly
        raise ArgumentError, 'ORDER BY clause requires at least one order item.' if @order_items.empty?
      end

      # Renders the ORDER BY clause.
      # @param query [Cyrel::Query] The query object for rendering expressions.
      # @return [String] The Cypher string fragment for the clause.
      def render(query)
        rendered_items = @order_items.map do |item|
          expression, direction = item
          rendered_expr = render_expression(expression, query)
          "#{rendered_expr} #{direction.to_s.upcase}"
        end.join(', ')

        "ORDER BY #{rendered_items}"
      end

      # Merging ORDER BY typically replaces the existing order.
      # @param other_order_by [Cyrel::Clause::OrderBy] The other OrderBy clause.
      def replace!(other_order_by)
        @order_items = other_order_by.order_items
        self
      end

      private

      def process_items(items)
        items.map do |item|
          unless item.is_a?(Array) && item.length == 2
            raise ArgumentError, "Invalid ORDER BY item format. Expected [expression, :asc/:desc], got #{item.inspect}"
          end

          expression, direction = item
          dir_sym = direction.to_s.downcase.to_sym
          raise ArgumentError, "Invalid ORDER BY direction: #{direction}. Use :asc or :desc." unless %i[asc desc].include?(dir_sym)

          [process_expression(expression), dir_sym]
        end
      end

      # Handles coercing the expression part of an order item.
      def process_expression(expression)
        case expression
        when Expression::Base
          expression
        when Symbol, String
          # Assume variable or simple property access string
          Return::RawIdentifier.new(expression.to_s) # Reuse from Return
        else
          Expression.coerce(expression)
        end
      end

      # Renders the expression part of an order item.
      def render_expression(expression, query)
        if expression.is_a?(Return::RawIdentifier)
        end
        expression.render(query)
      end
    end
  end
end
