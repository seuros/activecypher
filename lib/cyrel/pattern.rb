# frozen_string_literal: true

module Cyrel
  # Namespace for classes representing structural components of Cypher patterns
  # (nodes, relationships, paths).
  module Pattern
    # Validates that the given object is a usable pattern (Path, Node, or Relationship).
    # @param pattern [Object] The object to validate.
    # @param context [String] Label used in the error message (e.g. "CREATE", "MATCH").
    # @raise [ArgumentError] When the object is not a pattern.
    def self.assert_pattern!(pattern, context)
      return pattern if pattern.is_a?(Path) || pattern.is_a?(Node) || pattern.is_a?(Relationship)

      raise ArgumentError,
            "#{context} pattern must be a Cyrel::Pattern::Path, Node, or Relationship, got #{pattern.class}"
    end
  end
end
