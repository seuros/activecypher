# frozen_string_literal: true

module ActiveCypher
  module Fixtures
    # Evaluator orchestrates node and relationship creation for a fixture profile.
    class Evaluator
      def initialize(registry: Registry, node_builder: NodeBuilder.new, rel_builder: RelBuilder.new)
        @registry = registry
        @node_builder = node_builder
        @rel_builder = rel_builder
      end

      # Evaluate a sequence of DSL instructions (AST or direct calls).
      # Each instruction is a hash: { type: :node/:relationship, args: [...] }
      def evaluate(instructions)
        instructions.each do |inst|
          case inst[:type]
          when :node
            ref = inst[:ref]
            model_class = inst[:model_class]
            props = inst[:props]
            @node_builder.build(ref, model_class, props)
          when :relationship
            ref = inst[:ref]
            from_ref = inst[:from_ref]
            type = inst[:rel_type]
            to_ref = inst[:to_ref]
            props = inst[:props]
            @rel_builder.build(ref, from_ref, type, to_ref, props)
          else
            raise ArgumentError, "Unknown instruction type: #{inst[:type]}"
          end
        end
      end
    end
  end
end
