# frozen_string_literal: true

module Cyrel
  module AST
    class ReturnNode < ClauseNode
      attr_reader :items, :distinct

      def initialize(items, distinct: false)
        # items is an array of expressions/identifiers to return
        @items = items
        @distinct = distinct
      end

      protected

      def state
        [@items, @distinct]
      end
    end
  end
end
