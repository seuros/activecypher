# frozen_string_literal: true

module Cyrel
  module_function

  # Cyrel DSL helper: creates a new query.
  # Example: Cyrel.query.match(pattern)
  def query
    Query.new
  end

  # Cyrel DSL helper: alias for node creation.
  # Example: Cyrel.n(:person, :Person, name: 'Alice')
  def n(alias_name = nil, *labels, **properties)
    Pattern::Node.new(alias_name, labels: labels, properties: properties)
  end

  # Cyrel DSL helper: creates a CALL clause for a procedure.
  # Example: Cyrel.call('db.labels')
  def call(procedure)
    CallProcedure.new(procedure)
  end

  # Cyrel DSL helper: creates a RETURN clause.
  # Example: Cyrel.return(name: :n)
  def return(**return_values)
    ReturnOnly.new(return_values)
  end

  # Cyrel DSL helper: creates a node pattern.
  # Example: Cyrel.node(:n, :Person, name: 'Alice')
  def node(alias_name = nil, *labels, **properties)
    Pattern::Node.new(alias_name, labels: labels, properties: properties)
  end

  # Cyrel DSL helper: creates a relationship pattern.
  # Example: Cyrel.rel(:r, :KNOWS, since: 2020)
  def rel(alias_name = nil, *types, **properties)
    length = properties.delete(:length)
    Pattern::Relationship.new(alias_name: alias_name, types: types, properties: properties, length: length)
  end

  # Cyrel DSL helper: creates a path pattern with a DSL block.
  # Example: Cyrel.path { node(:a) > rel(:r) > node(:b) }
  def path(&)
    builder = PathBuilder.new
    builder.instance_eval(&)
    Pattern::Path.new(builder.elements)
  end

  # Path builder DSL for constructing path patterns
  class PathBuilder
    attr_reader :elements

    def initialize
      @elements = []
      @pending_direction = nil
    end

    def node(alias_name = nil, *labels, **properties)
      # If there's a pending direction, we need to add a relationship first
      if @pending_direction && @elements.any? && @elements.last.is_a?(Cyrel::Pattern::Node)
        @elements << Cyrel::Pattern::Relationship.new(types: [], direction: @pending_direction)
        @pending_direction = nil
      end

      n = Cyrel::Pattern::Node.new(alias_name, labels: labels, properties: properties)
      @elements << n
      self
    end

    def rel(alias_name = nil, *types, **properties)
      length = properties.delete(:length)

      # Check if we need to replace the last element (an anonymous relationship)
      if @elements.last.is_a?(Cyrel::Pattern::Relationship) && @elements.last.types.empty?
        # Replace the anonymous relationship with specified one, keeping direction
        direction = @elements.last.direction
        @elements.pop
      else
        direction = @pending_direction || :both
      end

      r = Cyrel::Pattern::Relationship.new(alias_name: alias_name, types: types, properties: properties, length: length, direction: direction)
      @elements << r
      @pending_direction = nil
      self
    end

    def >(_other)
      # When called like: node(:a) > rel(:r) > node(:b)
      # The rel(:r) is evaluated first, then > is called
      # So we need to modify the last relationship that was just added
      if @elements.last.is_a?(Cyrel::Pattern::Relationship)
        # Replace the last relationship with one that has the correct direction
        last_rel = @elements.pop
        new_rel = Cyrel::Pattern::Relationship.new(
          alias_name: last_rel.alias_name,
          types: last_rel.types,
          properties: last_rel.properties,
          length: last_rel.length,
          direction: :outgoing
        )
        @elements << new_rel
      else
        @pending_direction = :outgoing
      end
      self
    end

    def <(_other)
      # Same logic as > but for incoming direction
      if @elements.last.is_a?(Cyrel::Pattern::Relationship)
        last_rel = @elements.pop
        new_rel = Cyrel::Pattern::Relationship.new(
          alias_name: last_rel.alias_name,
          types: last_rel.types,
          properties: last_rel.properties,
          length: last_rel.length,
          direction: :incoming
        )
        @elements << new_rel
      else
        @pending_direction = :incoming
      end
      self
    end

    def -(_other)
      # Same logic as > but for bidirectional
      if @elements.last.is_a?(Cyrel::Pattern::Relationship)
        last_rel = @elements.pop
        new_rel = Cyrel::Pattern::Relationship.new(
          alias_name: last_rel.alias_name,
          types: last_rel.types,
          properties: last_rel.properties,
          length: last_rel.length,
          direction: :both
        )
        @elements << new_rel
      else
        @pending_direction = :both
      end
      self
    end
  end

  # Cyrel DSL helper: starts a CREATE query.
  # Example: Cyrel.create(pattern)
  def create(pattern)
    Query.new.create(pattern)
  end

  # Cyrel DSL helper: starts a MATCH query.
  # Example: Cyrel.match(pattern)
  def match(pattern, path_variable: nil)
    Query.new.match(pattern, path_variable: path_variable)
  end

  # Cyrel DSL helper: returns the element id of a node/relationship.
  # Example: Cyrel.id(:n)
  def id(...) = Functions.id(...)

  # Cyrel DSL helper: returns the element id of a node/relationship (alias).
  def element_id(...) = Functions.element_id(...)

  # Cyrel DSL helper: adapter-aware node ID function
  # Example: Cyrel.node_id(:n)
  def node_id(...) = Functions.node_id(...)

  # Cyrel DSL helper: creates a function call expression.
  # Example: Cyrel.function(:count, :*)
  def function(name, *args)
    Expression::FunctionCall.new(name, args)
  end

  # Cyrel DSL helper: Cypher count() aggregation.
  # Example: Cyrel.count(:n)
  def count(...) = Functions.count(...)

  # Cyrel DSL helper: Cypher labels() function.
  # Example: Cyrel.labels(:n)
  def labels(...) = Functions.labels(...)

  # Cyrel DSL helper: Cypher type() function.
  # Example: Cyrel.type(:r)
  def type(...) = Functions.type(...)

  # Cyrel DSL helper: Cypher properties() function.
  # Example: Cyrel.properties(:n)
  def properties(...) = Functions.properties(...)

  # Cyrel DSL helper: Cypher coalesce() function.
  # Example: Cyrel.coalesce(:a, :b)
  def coalesce(...) = Functions.coalesce(...)

  # Cyrel DSL helper: Cypher timestamp() function.
  # Example: Cyrel.timestamp
  def timestamp(...) = Functions.timestamp(...)

  # Cyrel DSL helper: Cypher toString() function.
  # Example: Cyrel.to_string(:n)
  def to_string(...) = Functions.to_string(...)

  # Cyrel DSL helper: Cypher toInteger() function.
  # Example: Cyrel.to_integer(:n)
  def to_integer(...) = Functions.to_integer(...)

  # Cyrel DSL helper: Cypher toFloat() function.
  # Example: Cyrel.to_float(:n)
  def to_float(...) = Functions.to_float(...)

  # Cyrel DSL helper: Cypher toBoolean() function.
  # Example: Cyrel.to_boolean(:n)
  def to_boolean(...) = Functions.to_boolean(...)

  # Cyrel DSL helper: Cypher sum() aggregation.
  # Example: Cyrel.sum(:n)
  def sum(...) = Functions.sum(...)

  # Cyrel DSL helper: Cypher avg() aggregation.
  # Example: Cyrel.avg(:n)
  def avg(...) = Functions.avg(...)

  # Cyrel DSL helper: Cypher min() aggregation.
  # Example: Cyrel.min(:n)
  def min(...) = Functions.min(...)

  # Cyrel DSL helper: Cypher max() aggregation.
  # Example: Cyrel.max(:n)
  def max(...) = Functions.max(...)

  # Cyrel DSL helper: Cypher collect() aggregation.
  # Example: Cyrel.collect(:n)
  def collect(...) = Functions.collect(...)

  # Cyrel DSL helper: Cypher size() function.
  # Example: Cyrel.size(:n)
  def size(...) = Functions.size(...)

  # Cyrel DSL helper: creates a PropertyAccess expression.
  # Example: Cyrel.prop(:n, :name)
  def prop(variable, property_name)
    Expression.prop(variable, property_name)
  end

  # Cyrel DSL helper: creates an Exists expression.
  # Example: Cyrel.exists(pattern)
  def exists(pattern)
    Expression.exists(pattern)
  end

  # Cyrel DSL helper: creates a Logical NOT expression.
  # Example: Cyrel.not(expression)
  def not(expression)
    Expression.not(expression)
  end

  # Cyrel DSL helper: property merging (SET n += {props}).
  # Use for updating only specified properties on a node or relationship.
  # Example: Cyrel.plus(:n) => { name: "Alice" } generates SET n += $p1
  def plus(variable)
    Plus.new(variable)
  end
end
