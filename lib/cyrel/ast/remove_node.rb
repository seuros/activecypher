# frozen_string_literal: true

module Cyrel
  module AST
    # AST node for REMOVE clauses
    # For when you need to Marie Kondo your graph properties and labels
    class RemoveNode < ClauseNode
      attr_reader :items

      def initialize(items)
        @items = items
      end

      protected

      def state
        [@items]
      end
    end
  end
end
