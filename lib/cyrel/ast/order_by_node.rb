# frozen_string_literal: true

module Cyrel
  module AST
    class OrderByNode < ClauseNode
      attr_reader :items

      def initialize(items)
        # items is an array of [expression, direction] pairs
        # e.g., [[expr1, :asc], [expr2, :desc]]
        @items = items
      end

      protected

      def state
        [@items]
      end
    end
  end
end
