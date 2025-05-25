# frozen_string_literal: true

module Cyrel
  module AST
    # AST node for CALL clauses (procedures)
    # For when you need to call upon the powers that be
    class CallNode < Node
      attr_reader :procedure_name, :arguments, :yield_items

      def initialize(procedure_name, arguments: [], yield_items: nil)
        @procedure_name = procedure_name
        @arguments = arguments
        @yield_items = yield_items
      end

      protected

      def state
        [@procedure_name, @arguments, @yield_items]
      end
    end

    # AST node for CALL subqueries
    # For when you need a query within a query (queryception)
    class CallSubqueryNode < Node
      attr_reader :subquery

      def initialize(subquery)
        @subquery = subquery
      end

      protected

      def state
        [@subquery]
      end
    end
  end
end
