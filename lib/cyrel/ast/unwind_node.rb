# frozen_string_literal: true

module Cyrel
  module AST
    class UnwindNode < ClauseNode
      attr_reader :expression, :alias_name

      def initialize(expression, alias_name)
        @expression = expression
        @alias_name = alias_name
      end

      protected

      def state
        [@expression, @alias_name]
      end
    end
  end
end
