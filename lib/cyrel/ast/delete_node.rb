# frozen_string_literal: true

module Cyrel
  module AST
    # AST node for DELETE and DETACH DELETE clauses
    # Because sometimes things need to disappear, with or without their relationships
    class DeleteNode < ClauseNode
      attr_reader :variables, :detach

      def initialize(variables, detach: false)
        @variables = variables
        @detach = detach
      end

      protected

      def state
        [@variables, @detach]
      end
    end
  end
end
