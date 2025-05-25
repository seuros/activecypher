# frozen_string_literal: true

module Cyrel
  module AST
    # AST node for FOREACH clause (extension)
    # For when you need to iterate through a list and make changes
    class ForeachNode < ClauseNode
      attr_reader :variable, :expression, :update_clauses

      def initialize(variable, expression, update_clauses)
        @variable = variable
        @expression = expression
        @update_clauses = update_clauses
      end

      protected

      def state
        [@variable, @expression, @update_clauses]
      end
    end
  end
end
