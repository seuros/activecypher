# frozen_string_literal: true

module Cyrel
  module_function

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
  # Example: Cyrel.node(:n, labels: ['Person'], properties: {name: 'Alice'})
  def node(alias_name, labels: [], properties: {})
    Pattern::Node.new(alias_name, labels: labels, properties: properties)
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
  def id(...) = Functions.element_id(...)

  # Cyrel DSL helper: returns the element id of a node/relationship (alias).
  def element_id(...) = Functions.element_id(...)

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
