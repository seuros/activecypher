# frozen_string_literal: true

module Cyrel
  module AST
    # AST node for UNION and UNION ALL clauses
    # Because sometimes you need to combine queries like a database DJ
    class UnionNode < ClauseNode
      attr_reader :queries, :all

      def initialize(queries, all: false)
        @queries = queries
        @all = all
      end

      protected

      def state
        [@queries, @all]
      end
    end
  end
end
