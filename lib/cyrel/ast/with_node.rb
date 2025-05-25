# frozen_string_literal: true

module Cyrel
  module AST
    class WithNode < ClauseNode
      attr_reader :items, :distinct, :where_conditions

      def initialize(items, distinct: false, where_conditions: nil)
        # items is an array of expressions/identifiers to project
        @items = items
        @distinct = distinct
        # where_conditions can be nil or an array of expressions
        @where_conditions = where_conditions
      end

      protected

      def state
        [@items, @distinct, @where_conditions]
      end
    end
  end
end
