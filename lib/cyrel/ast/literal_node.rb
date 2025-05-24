# frozen_string_literal: true

module Cyrel
  module AST
    # Immutable AST node for literal values using Ruby's Data class
    # Because sometimes you just want to say what you mean, immutably
    LiteralNode = Data.define(:value) do
      def accept(visitor)
        visitor.visit_literal_node(self)
      end

      def to_ast
        self
      end

      # Pattern matching support
      def deconstruct
        [value]
      end

      def deconstruct_keys(keys)
        { value: value }
      end

      # Type inference
      def inferred_type
        case value
        when String then :string
        when Symbol then :parameter
        when Integer then :integer
        when Float then :float
        when TrueClass, FalseClass then :boolean
        when NilClass then :null
        else :unknown
        end
      end
    end
  end
end
