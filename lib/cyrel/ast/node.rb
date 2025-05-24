# frozen_string_literal: true

module Cyrel
  module AST
    # Base class for all AST nodes
    # Because every tree needs roots, even if they're just pretending to be organized
    class Node
      # Accept a visitor for the visitor pattern
      # It's like accepting guests, but these guests judge your entire structure
      def accept(visitor)
        method_name = "visit_#{self.class.name.demodulize.underscore}"
        if visitor.respond_to?(method_name)
          visitor.send(method_name, self)
        else
          raise NotImplementedError,
                "Visitor #{visitor.class} doesn't know how to visit #{self.class}. " \
                "Did you forget to implement #{method_name}?"
        end
      end

      # Equality for testing and debugging
      # Because sometimes you need to know if two trees fell in the same forest
      def ==(other)
        self.class == other.class && state == other.state
      end

      protected

      # Override in subclasses to define equality state
      # The essence of what makes this node unique, like a fingerprint but less criminal
      def state
        instance_variables.map { |var| instance_variable_get(var) }
      end
    end

    # Base class for clause nodes (MATCH, WHERE, RETURN, etc.)
    # The building blocks of your query, like LEGO but with more existential dread
    class ClauseNode < Node
    end

    # Base class for expression nodes (literals, comparisons, functions, etc.)
    # Where math meets philosophy and neither wins
    class ExpressionNode < Node
    end

    # Base class for pattern nodes (nodes, relationships, paths)
    # Because graphs need patterns like developers need coffee
    class PatternNode < Node
    end
  end
end
