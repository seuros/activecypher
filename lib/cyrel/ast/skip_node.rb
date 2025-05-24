# frozen_string_literal: true

module Cyrel
  module AST
    class SkipNode < ClauseNode
      attr_reader :amount

      def initialize(amount)
        @amount = amount
      end

      protected

      def state
        [@amount]
      end
    end
  end
end
