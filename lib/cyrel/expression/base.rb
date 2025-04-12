# frozen_string_literal: true

module Cyrel
  module Expression
    # Base class/module for all expression types.
    # Defines the common interface, primarily the `render` method.
    class Base
      # Renders the expression into its Cypher string representation.
      # Subclasses must implement this method.
      # @param query [Cyrel::Query] The query object, used for parameter registration if needed.
      # @return [String] The Cypher string fragment for the expression.
      def render(query)
        raise NotImplementedError, "#{self.class} must implement the 'render' method"
      end

      # --- Operator Overloading for DSL ---
      # These methods allow building expression trees more naturally,
      # e.g., Cyrel.prop(:n, :age) > 18

      def >(other)
        Comparison.new(self, :>, other)
      end

      def >=(other)
        Comparison.new(self, :>=, other)
      end

      def <(other)
        Comparison.new(self, :<, other)
      end

      def <=(other)
        Comparison.new(self, :<=, other)
      end

      def ==(other)
        Comparison.new(self, :"=", other) # Use = for Cypher equality
      end

      def !=(other)
        Comparison.new(self, :"<>", other) # Use <> for Cypher inequality
      end

      def =~(other)
        Comparison.new(self, :"=~", other) # Regex match
      end

      def +(other)
        Operator.new(self, :+, other)
      end

      def -(other)
        Operator.new(self, :-, other)
      end

      def *(other)
        Operator.new(self, :*, other)
      end

      def /(other)
        Operator.new(self, :/, other)
      end

      def %(other)
        Operator.new(self, :%, other)
      end

      def ^(other)
        Operator.new(self, :^, other) # Exponentiation
      end

      # Logical operators require special handling as Ruby's `and`, `or`, `not`
      # have different precedence and short-circuiting behavior.
      # We use `&` for AND and `|` for OR. `!` is handled separately if needed.

      def &(other)
        Logical.new(self, :AND, other)
      end

      def |(other)
        Logical.new(self, :OR, other)
      end

      # Add more operators as needed (e.g., IN, STARTS WITH, CONTAINS, ENDS WITH)
      # These might be better represented as specific Comparison or FunctionCall types.

      # NOTE: `coerce` method moved to the Expression module itself.
    end
  end
end
