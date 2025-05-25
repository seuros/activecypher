# frozen_string_literal: true

module Cyrel
  module AST
    class WhereNode < ClauseNode
      attr_reader :conditions

      def initialize(conditions)
        # conditions is an array of expression objects
        @conditions = conditions
      end

      protected

      def state
        [@conditions]
      end
    end
  end
end
