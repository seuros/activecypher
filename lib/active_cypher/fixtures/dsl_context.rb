# frozen_string_literal: true

module ActiveCypher
  module Fixtures
    # Context for evaluating fixture profile DSL files.
    # Provides node and relationship methods for use in profiles.
    class DSLContext
      attr_reader :nodes, :relationships

      def initialize
        @nodes = []
        @relationships = []
        @refs = {}
      end

      # DSL: node :ref, ModelClass, props
      def node(ref, model_class, **props)
        raise ArgumentError, "Duplicate node ref: #{ref.inspect}" if @refs.key?(ref)

        @refs[ref] = :node
        @nodes << { ref: ref, model_class: model_class, props: props }
      end

      # DSL: relationship :ref, :from_ref, :TYPE, :to_ref, props
      def relationship(ref, from_ref, type, to_ref, **props)
        raise ArgumentError, "Duplicate relationship ref: #{ref.inspect}" if @refs.key?(ref)
        raise ArgumentError, "Unknown from_ref: #{from_ref.inspect}" unless @refs.key?(from_ref)
        raise ArgumentError, "Unknown to_ref: #{to_ref.inspect}" unless @refs.key?(to_ref)

        @refs[ref] = :relationship
        @relationships << {
          ref: ref,
          from_ref: from_ref,
          type: type,
          to_ref: to_ref,
          props: props
        }
      end
    end
  end
end
