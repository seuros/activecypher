# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a standalone CALL procedure clause.
    # Example: CALL db.labels() YIELD label WHERE label STARTS WITH 'X' RETURN label
    class Call < Base
      attr_reader :procedure_name, :arguments, :yield_items, :where_clause, :return_clause

      # @param procedure_name [String] The name of the procedure (e.g., "db.labels").
      # @param arguments [Array] Arguments to pass to the procedure (will be parameterized).
      # @param yield_items [Array<String>, String, nil] Raw string(s) for the YIELD part (e.g., "label", ["id", "name AS nodeName"]).
      # @param where_clause [Cyrel::Clause::Where, nil] Optional WHERE clause applied after YIELD.
      # @param return_clause [Cyrel::Clause::Return, nil] Optional RETURN clause applied after WHERE/YIELD.
      def initialize(procedure_name, arguments: [], yield_items: nil, where: nil, return_items: nil)
        @procedure_name = procedure_name
        @arguments = arguments # Store raw arguments, parameterize during render
        @yield_items = yield_items ? Array(yield_items).join(', ') : nil # Simple string join for now

        @where_clause = case where
                        when Clause::Where then where
                        when nil then nil
                        else Clause::Where.new(*Array(where)) # Coerce Hash/Array/Expression
                        end

        @return_clause = case return_items
                         when Clause::Return then return_items
                         when nil then nil
                         else Clause::Return.new(*Array(return_items))
                         end
      end

      def render(query)
        rendered_args = @arguments.map { |arg| Expression.coerce(arg).render(query) }.join(', ')
        call_part = "CALL #{@procedure_name}(#{rendered_args})"
        yield_part = @yield_items ? " YIELD #{@yield_items}" : ''
        where_part = @where_clause ? " #{@where_clause.render(query)}" : '' # Render WHERE clause
        return_part = @return_clause ? " #{@return_clause.render(query)}" : '' # Render RETURN clause

        # Ensure correct ordering and spacing
        parts = [call_part, yield_part, where_part, return_part]
        parts.compact.reject(&:empty?).join # Join non-empty parts without extra spaces
      end
    end
  end
end
