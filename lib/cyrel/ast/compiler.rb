# frozen_string_literal: true

require_relative 'node'
require_relative 'literal_node'
require 'concurrent' if defined?(Concurrent)

module Cyrel
  module AST
    # Compiles AST nodes into Cypher queries with optional thread-safety
    # It's like Google Translate, but for graph databases and with more reliable results
    class Compiler
      attr_reader :output, :parameters

      def initialize
        @output = StringIO.new
        if defined?(Concurrent)
          @parameters = Concurrent::Hash.new
          @param_counter = Concurrent::AtomicFixnum.new(0)
        else
          @parameters = {}
          @param_counter = 0
        end
        @first_clause = true
      end

      # Compile an AST node or array of nodes
      # Returns [cypher_string, parameters_hash]
      def compile(node_or_nodes)
        nodes = Array(node_or_nodes)

        nodes.each do |node|
          add_clause_separator unless @first_clause
          node.accept(self)
          @first_clause = false
        end

        [@output.string, @parameters]
      end

      # Visit a LIMIT node
      # Because sometimes less is more, except in this comment
      def visit_limit_node(node)
        @output << 'LIMIT '
        render_expression(node.expression)
      end

      # Visit a SKIP node
      # For when you want to jump ahead in your results
      def visit_skip_node(node)
        @output << 'SKIP '
        render_expression(node.amount)
      end

      # Visit a literal value node
      # The most honest node in the entire tree
      def visit_literal_node(node)
        if node.value.is_a?(Symbol)
          # Symbols are parameter references, not values to be parameterized
          @output << "$#{node.value}"
        else
          # All other literals become parameters for consistency with existing behavior
          param_key = register_parameter(node.value)
          @output << "$#{param_key}"
        end
      end

      private

      def add_clause_separator
        @output << "\n"
      end

      # Render an expression (could be a literal, parameter, property access, etc.)
      def render_expression(expr)
        case expr
        in Node
          # It's already an AST node
          expr.accept(self)
        in Symbol | Numeric | String | true | false | nil
          # Wrap in literal node and visit
          LiteralNode.new(expr).accept(self)
        in { to_ast: }
          # Has a to_ast method
          expr.to_ast.accept(self)
        else
          raise "Don't know how to render expression: #{expr.inspect}"
        end
      end

      # Register a parameter and return its key (thread-safe if Concurrent is available)
      # Because $p1, $p2, $p3 is the naming convention we deserve
      def register_parameter(value)
        if defined?(Concurrent) && @parameters.is_a?(Concurrent::Hash)
          # Thread-safe parameter registration
          existing_key = @parameters.key(value)
          return existing_key if existing_key
          
          counter = @param_counter.increment
          key = :"p#{counter}"
          @parameters[key] = value
          key
        else
          # Non-concurrent version
          existing_key = @parameters.key(value)
          return existing_key if existing_key

          @param_counter += 1
          key = :"p#{@param_counter}"
          @parameters[key] = value
          key
        end
      end
    end
  end
end
