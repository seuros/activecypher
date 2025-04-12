# frozen_string_literal: true

module Cyrel
  module Expression
    # Represents a literal value (String, Number, Boolean, Nil, Array, Map) in a Cypher query.
    # Literals are typically converted into parameters.
    class Literal < Base
      attr_reader :value

      def initialize(value)
        # We don't validate the type here extensively, assuming Neo4j driver
        # or the database itself will handle type compatibility.
        # We could add checks for common unsupported types if needed.
        @value = value
      end

      # Renders the literal by registering it as a parameter.
      # @param query [Cyrel::Query] The query object for parameter registration.
      # @return [String] The parameter placeholder string (e.g., "$p1").
      def render(query)
        # Special handling for NULL as it doesn't use a parameter
        return 'NULL' if @value.nil?

        param_key = query.register_parameter(@value)
        "$#{param_key}"
      end

      # Override comparison methods for direct literal comparison if needed,
      # although the Base class methods creating Comparison objects are generally preferred.
      # Example: def ==(other) ... end
    end
  end
end
