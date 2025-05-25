# frozen_string_literal: true

module Cyrel
  module AST
    # AST node for MERGE clauses
    # For when you want to find or create, the Schrödinger's cat of graph operations
    class MergeNode < ClauseNode
      attr_reader :pattern, :on_create, :on_match

      def initialize(pattern, on_create: nil, on_match: nil)
        @pattern = pattern
        @on_create = on_create
        @on_match = on_match
      end

      protected

      def state
        [@pattern, @on_create, @on_match]
      end
    end
  end
end
