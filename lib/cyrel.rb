# frozen_string_literal: true

module Cyrel
  # Define all top-level helpers as instance methods first
  def call(procedure)
    CallProcedure.new(procedure)
  end

  def return(**return_values)
    ReturnOnly.new(return_values)
  end
  # Now make all defined instance methods module functions

  module_function

  # --- Function Helpers (Delegated) ---
  def id(...) = Functions.id(...)
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
