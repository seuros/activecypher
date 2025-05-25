# frozen_string_literal: true

module Cyrel
  module AST
    # Compiler that integrates with the Query's parameter system
    # Like a diplomat that speaks both AST and Query fluently
    class QueryIntegratedCompiler < Compiler
      attr_reader :query

      def initialize(query)
        super()
        @query = query
      end

      protected

      # Override to use the query's parameter registration
      def register_parameter(value)
        @query.register_parameter(value)
      end
    end
  end
end
