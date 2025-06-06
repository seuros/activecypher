# frozen_string_literal: true

module Cyrel
  # Provides helper methods for creating Cypher function call expressions.
  module Functions
    # Represents the Cypher '*' literal, often used in count(*).
    # We use a specific object to differentiate it from a string literal "*".
    ASTERISK = Object.new
    # Special render for asterisk
    def ASTERISK.render(_query) = '*'
    # Act like an expression
    def ASTERISK.is_a?(klass) = klass == Cyrel::Expression::Base || super

    ASTERISK.freeze

    module_function

    # --- Common Cypher Functions ---

    # Use elementId() instead of deprecated id()
    # @deprecated Use {#node_id} instead for adapter-aware ID handling
    def element_id(node_variable)
      Expression::FunctionCall.new(:elementId, Clause::Return::RawIdentifier.new(node_variable.to_s))
    end

    # @deprecated Use {#node_id} instead for adapter-aware ID handling
    def id(node_variable)
      Expression::FunctionCall.new(:id, Clause::Return::RawIdentifier.new(node_variable.to_s))
    end

    # Adapter-aware node ID function
    # Generates a placeholder that will be replaced by the correct ID function
    # at execution time based on the database adapter (Neo4j vs Memgraph)
    # Because databases can't agree on how to name their ID functions,
    # we'll just pretend they're all the same and fix it later
    def node_id(node_variable)
      Expression::FunctionCall.new(:__NODE_ID__, Clause::Return::RawIdentifier.new(node_variable.to_s))
    end

    # Because apparently, COUNT(*) isn’t obvious enough.
    # Handles the 'give me everything and make it snappy' use case.
    def count(expression, distinct: false)
      # Handle count(*) specifically
      expr_arg = case expression
                 when :* then ASTERISK
                 when Symbol, String then Clause::Return::RawIdentifier.new(expression.to_s) # Convert symbol/string to RawIdentifier
                 else expression # Assume it's already an Expression object (like PropertyAccess)
                 end
      Expression::FunctionCall.new(:count, expr_arg, distinct: distinct)
    end

    # Retrieves labels from a node. You could also just... ask the node. But noooo.
    # Instead, we call a function and pretend we're not slowly dying inside.
    def labels(node_variable)
      Expression::FunctionCall.new(:labels, node_variable)
    end

    def type(relationship_variable)
      Expression::FunctionCall.new(:type, relationship_variable)
    end

    def properties(variable)
      Expression::FunctionCall.new(:properties, variable)
    end

    # Returns the first non-null expression.
    # The Cypher equivalent of settling.
    def coalesce(*expressions)
      Expression::FunctionCall.new(:coalesce, expressions)
    end

    def timestamp
      Expression::FunctionCall.new(:timestamp)
    end

    def to_string(expression)
      Expression::FunctionCall.new(:toString, expression)
    end

    # Converts a thing into an integer.
    # Great for when your data is having an identity crisis and just wants to be whole again.
    def to_integer(expression)
      Expression::FunctionCall.new(:toInteger, expression)
    end

    def to_float(expression)
      Expression::FunctionCall.new(:toFloat, expression)
    end

    def to_boolean(expression)
      Expression::FunctionCall.new(:toBoolean, expression)
    end

    # --- Aggregation Functions ---

    def sum(expression, distinct: false)
      Expression::FunctionCall.new(:sum, expression, distinct: distinct)
    end

    def avg(expression, distinct: false)
      Expression::FunctionCall.new(:avg, expression, distinct: distinct)
    end

    def min(expression)
      Expression::FunctionCall.new(:min, expression)
    end

    def max(expression)
      Expression::FunctionCall.new(:max, expression)
    end

    def collect(expression, distinct: false)
      Expression::FunctionCall.new(:collect, expression, distinct: distinct)
    end

    # --- List Functions ---
    # Add common list functions like size(), keys(), range(), etc. as needed

    def size(expression)
      Expression::FunctionCall.new(:size, expression)
    end

    # --- String Functions ---
    # Add common string functions like substring(), replace(), toLower(), etc. as needed

    # --- Spatial/Temporal/etc. Functions ---
    # Add other function categories as required by ActiveCypher
  end
end
