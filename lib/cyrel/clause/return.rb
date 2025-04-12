# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a RETURN clause in a Cypher query.
    class Return < Base
      attr_reader :items, :distinct

      # Initializes a RETURN clause.
      # @param items [Array<Cyrel::Expression::Base, Object, String, Symbol>]
      #   Items to return. Non-Expression objects are coerced.
      #   Strings/Symbols can represent variables or simple property access (though Expressions are preferred).
      # @param distinct [Boolean] Whether to return distinct results.
      def initialize(*items, distinct: false)
        @items = process_items(items.flatten)
        @distinct = distinct
        raise ArgumentError, 'RETURN clause requires at least one item.' if @items.empty?
      end

      # Renders the RETURN clause.
      # @param query [Cyrel::Query] The query object for rendering expressions.
      # @return [String] The Cypher string fragment for the clause.
      def render(query)
        distinct_str = @distinct ? 'DISTINCT ' : ''
        rendered_items = @items.map { |item| render_item(item, query) }.join(', ')
        "RETURN #{distinct_str}#{rendered_items}"
      end

      # Merges items from another Return clause.
      # Simple concatenation, assumes user handles potential duplicates if needed.
      # @param other_return [Cyrel::Clause::Return] The other Return clause to merge.
      def merge!(other_return)
        @items.concat(other_return.items)
        # Decide on distinct status - prioritize true if either has it?
        # Or maybe raise error if distinct statuses conflict?
        # For now, let's keep the original distinct status.
        # @distinct ||= other_return.distinct
        self
      end

      private

      # Processes input items, coercing them into appropriate Expression types
      # or handling simple variable names.
      def process_items(items)
        items.map do |item|
          case item
          when Expression::Base
            item
          when Symbol, String
            # Could represent a variable, alias, or function call string.
            # For simplicity, treat as a literal string expression for now.
            # A more robust solution might try to parse/identify these.
            # Or require users to use Cyrel.prop or Cyrel.func for clarity.
            # Let's create a simple Variable expression type? Or just Literal?
            # Using Literal for now, assuming it's a variable name.
            Expression::Literal.new(item.to_s) # Render as "$param" - NO, this is wrong.
            # We need a way to represent a raw variable/alias.
            # Let's create a simple RawExpression internal class or similar.
            RawIdentifier.new(item.to_s)
          else
            Expression.coerce(item) # Coerce other types (numbers, etc.)
          end
        end
      end

      # Renders a single return item.
      def render_item(item, query)
        # Handle our internal RawIdentifier type
        if item.is_a?(RawIdentifier)
          item.identifier
        else
          item.render(query)
        end
      end

      # Simple internal class to represent a raw identifier (variable/alias)
      # that should not be parameterized or quoted.
      class RawIdentifier < Expression::Base
        attr_reader :identifier

        def initialize(identifier)
          @identifier = identifier
        end

        def render(_query) = @identifier
      end
    end
  end
end
