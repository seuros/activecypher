# frozen_string_literal: true

require_relative 'node'

module Cyrel
  module AST
    # AST node for LIMIT clause
    # For when you want boundaries, even in your queries
    class LimitNode < ClauseNode
      attr_reader :expression

      def initialize(expression)
        @expression = expression
      end

      protected

      def state
        [@expression]
      end
    end
  end
end
