# frozen_string_literal: true

require_relative 'compiler'
require_relative 'query_integrated_compiler'
require_relative 'simple_cache'

module Cyrel
  module AST
    # Adapter that allows AST nodes to work with the existing clause-based system
    # Now with simple caching for performance
    class ClauseAdapter < Clause::Base
      attr_reader :ast_node

      def initialize(ast_node)
        @ast_node = ast_node
        @ast_node_hash = ast_node.hash
        super()
      end

      def render(query)
        # Use a simple cache key based on AST node structure
        cache_key = [@ast_node_hash, @ast_node.class.name].join(':')
        
        SimpleCache.instance.fetch(cache_key) do
          # Create a compiler that delegates parameter registration to the query
          compiler = QueryIntegratedCompiler.new(query)
          compiler.compile(ast_node)
          compiler.output.string
        end
      end

      # Ruby 3.0+ pattern matching support
      def deconstruct
        [ast_node]
      end

      def deconstruct_keys(keys)
        { ast_node: ast_node, type: ast_node.class }
      end
    end
  end
end
