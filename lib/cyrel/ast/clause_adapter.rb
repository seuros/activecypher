# frozen_string_literal: true

module Cyrel
  module AST
    # Adapter that allows AST nodes to work with the existing clause-based system
    # Now with simple caching for performance
    class ClauseAdapter < Clause::Base
      attr_reader :ast_node

      def initialize(ast_node)
        @ast_node = ast_node
        super()
      end

      def render(query)
        # Create a compiler that delegates parameter registration to the query
        compiler = QueryIntegratedCompiler.new(query)
        compiler.compile(ast_node)
        compiler.output.string
      end

      # Ruby 3.0+ pattern matching support
      def deconstruct
        [ast_node]
      end

      def deconstruct_keys(_keys)
        { ast_node: ast_node, type: ast_node.class }
      end
    end
  end
end
