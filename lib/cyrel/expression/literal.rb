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
        # nil is special - render as NULL literal, not a parameter
        return 'NULL' if @value.nil?

        param_key = query.register_parameter(@value)

        # If the param_key is the same as the value (for loop variables),
        # don't add the $ prefix - just render as identifier
        if param_key == @value && @value.is_a?(Symbol)
          param_key.to_s
        else
          "$#{param_key}"
        end
      end

      # Override comparison methods for direct literal comparison if needed,
      # although the Base class methods creating Comparison objects are generally preferred.
      # Example: def ==(other) ... end
    end
  end
end
