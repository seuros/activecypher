# frozen_string_literal: true

module Cyrel
  module AST
    # AST node for MATCH and OPTIONAL MATCH clauses
    # Because finding things in graphs is what we're all about
    class MatchNode < ClauseNode
      attr_reader :pattern, :optional, :path_variable

      def initialize(pattern, optional: false, path_variable: nil)
        @pattern = pattern
        @optional = optional
        @path_variable = path_variable
      end

      protected

      def state
        [@pattern, @optional, @path_variable]
      end
    end
  end
end
