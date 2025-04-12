# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a WITH clause in a Cypher query.
    # Used to project results from one part of a query to the next.
    class With < Base
      attr_reader :items, :distinct, :where # Allow optional WHERE after WITH

      # Initializes a WITH clause.
      # @param items [Array<Cyrel::Expression::Base, Object, String, Symbol>]
      #   Items to project. Similar handling to RETURN items.
      #   Can include aliases using 'AS', e.g., "count(n) AS node_count".
      # @param distinct [Boolean] Whether to project distinct results.
      # @param where [Cyrel::Clause::Where, nil] An optional WHERE clause to apply after WITH.
      def initialize(*items, distinct: false, where: nil)
        @items = process_items(items.flatten)
        @distinct = distinct
        @where = where # Store the Where clause instance directly
        raise ArgumentError, 'WITH clause requires at least one item.' if @items.empty?
        return if where.nil? || where.is_a?(Cyrel::Clause::Where)

        raise ArgumentError, 'WHERE clause for WITH must be a Cyrel::Clause::Where instance.'
      end

      # Renders the WITH clause, including an optional subsequent WHERE.
      # @param query [Cyrel::Query] The query object for rendering expressions.
      # @return [String] The Cypher string fragment for the clause.
      def render(query)
        distinct_str = @distinct ? 'DISTINCT ' : ''
        # Need to handle aliases (AS keyword) properly here.
        # The simple RawIdentifier might not be enough if we need parsing.
        # Let's assume for now items can be strings like "n.name AS name".
        rendered_items = @items.map { |item| render_item(item, query) }.join(', ')

        with_part = "WITH #{distinct_str}#{rendered_items}"
        where_part = @where ? "\n#{@where.render(query)}" : '' # Render WHERE on new line

        "#{with_part}#{where_part}"
      end

      # Merging WITH clauses is complex. Appending might be simplest, but
      # alias conflicts and projection logic need careful consideration.
      # For now, let's not support merging directly on the clause.
      # Query#merge! will handle combining multiple WITH clauses if needed.
      # def merge!(other_with) ... end

      private

      # Processes input items, similar to Return clause.
      # Needs enhancement to handle aliases ('AS').
      def process_items(items)
        items.map do |item|
          case item
          when Expression::Base
            item
          when String
            # Basic check for ' AS ' - assumes case-insensitivity handled by Cypher
            if item.match?(/\s+as\s+/i)
              # Treat as raw string for now, includes the alias
              RawExpressionString.new(item)
            else
              # Assume it's a variable/identifier
              Return::RawIdentifier.new(item) # Reuse from Return
            end
          when Symbol
            Return::RawIdentifier.new(item.to_s)
          else
            Expression.coerce(item)
          end
        end
      end

      # Renders a single WITH item.
      def render_item(item, query)
        if item.is_a?(Return::RawIdentifier) || item.is_a?(RawExpressionString)
        end
        item.render(query)
      end

      # Simple internal class to represent a raw expression string
      # that might contain aliases and should not be parameterized/quoted directly.
      class RawExpressionString < Expression::Base
        attr_reader :expression_string

        def initialize(expression_string)
          @expression_string = expression_string
        end

        def render(_query) = @expression_string
      end
    end
  end
end
