# frozen_string_literal: true

module Cyrel
  module AST
    # Compiler that integrates with the Query's parameter system
    # Like a diplomat that speaks both AST and Query fluently
    class QueryIntegratedCompiler < Compiler
      attr_reader :query

      def initialize(query)
        # Store current loop_variables before calling super
        old_loop_variables = @loop_variables
        super()
        @query = query
        # Restore loop_variables if they were set before initialization
        @loop_variables = old_loop_variables if old_loop_variables
      end

      protected

      # Override to use the query's parameter registration
      def register_parameter(value)
        @query.register_parameter(value)
      end
    end
  end
end
