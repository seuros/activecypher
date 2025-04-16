# frozen_string_literal: true

require 'irb' # Required for binding.irb

module Cyrel
  module_function

  # Define all top-level helpers as instance methods first
  def call(procedure)
    CallProcedure.new(procedure)
  end

  def return(**return_values)
    ReturnOnly.new(return_values)
  end
  # Now make all defined instance methods module functions

  # --- Pattern Helpers ---
  def node(alias_name, labels: [], properties: {})
    Pattern::Node.new(alias_name, labels: labels, properties: properties)
  end
  # Add helpers for Relationship, Path if needed

  # --- Query Building Starters ---
  def create(pattern)
    Query.new.create(pattern) # Start a new query and call create
  end

  def match(pattern, path_variable: nil)
    Query.new.match(pattern, path_variable: path_variable) # Start a new query and call match
  end
  # Add helpers for merge etc. if desired as query starters

  # --- Function Helpers (Delegated) ---
  # Keep id for now for compatibility? Or remove entirely? Let's keep it but delegate element_id too.
  # Delegate to the correct module function
  def id(...) = Functions.element_id(...)
  def element_id(...) = Functions.element_id(...)
  def count(...) = Functions.count(...)
  def labels(...) = Functions.labels(...)
  def type(...) = Functions.type(...)
  def properties(...) = Functions.properties(...)
  def coalesce(...) = Functions.coalesce(...)
  def timestamp(...) = Functions.timestamp(...)
  def to_string(...) = Functions.to_string(...)
  def to_integer(...) = Functions.to_integer(...)
  def to_float(...) = Functions.to_float(...)
  def to_boolean(...) = Functions.to_boolean(...)
  def sum(...) = Functions.sum(...)
  def avg(...) = Functions.avg(...)
  def min(...) = Functions.min(...)
  def max(...) = Functions.max(...)
  def collect(...) = Functions.collect(...)
  def size(...) = Functions.size(...)

  # --- Expression Helpers (Delegated) ---

  # Helper for creating PropertyAccess expressions.
  def prop(variable, property_name)
    Expression.prop(variable, property_name)
  end

  # Helper for creating Exists expressions.
  def exists(pattern)
    Expression.exists(pattern)
  end

  # Helper for creating Logical NOT expressions.
  def not(expression)
    Expression.not(expression)
  end
end
