# frozen_string_literal: true

module Cyrel
  module AST
    class SetNode < ClauseNode
      attr_reader :assignments

      def initialize(assignments)
        # assignments is an array of processed assignment tuples
        @assignments = assignments
      end

      protected

      def state
        [@assignments]
      end
    end
  end
end
