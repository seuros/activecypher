# frozen_string_literal: true

module Cyrel
  module AST
    # AST node for CREATE clauses
    # Because sometimes you need to make things exist
    class CreateNode < ClauseNode
      attr_reader :pattern

      def initialize(pattern)
        @pattern = pattern
      end

      protected

      def state
        [@pattern]
      end
    end
  end
end
