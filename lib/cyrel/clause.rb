# frozen_string_literal: true

module Cyrel
  # Namespace for classes representing individual Cypher clauses (MATCH, WHERE, RETURN, etc.).
  module Clause
    # Abstract base class for all Cypher clauses.
    class Base
      # Renders the specific Cypher clause fragment.
      # Subclasses must implement this method.
      # @param query [Cyrel::Query] The query object, used for parameter registration
      #   and potentially accessing query state (like defined aliases).
      # @return [String, nil] The Cypher string fragment for this clause, or nil if the clause is empty/not applicable.
      def render(query)
        raise NotImplementedError, "#{self.class} must implement the 'render' method"
      end

      # Optional: Define a common interface for merging clauses if needed,
      # though specific logic might vary significantly between clause types.
      # def merge!(other_clause)
      #   raise NotImplementedError, "#{self.class} does not support merging"
      # end
    end
  end
end
