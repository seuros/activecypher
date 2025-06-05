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
        Comparison.new(self, :'=', other) # Use = for Cypher equality
      end
      # alias_method must be called at the class level, not inside a method

      def !=(other)
        Comparison.new(self, :'<>', other) # Use <> for Cypher inequality
      end

      def =~(other)
        Comparison.new(self, :=~, other) # Regex match
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
      # Add eq as an alias for == at the class level
      alias eq ==

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
    end

    # Creates an aliased version of this expression.
    # @param alias_name [Symbol, String] The alias to assign.
    # @return [Cyrel::Expression::Alias]
    def as(alias_name)
      Alias.new(self, alias_name)
    end
  end
end
