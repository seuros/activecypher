# frozen_string_literal: true

# Subclasses are autoloaded by Zeitwerk based on constant usage.
# Explicit requires removed.

module Cyrel
  # Namespace for classes representing expressions in Cypher queries.
  # Expressions are parts of a query that evaluate to a value or condition.
  # Examples: property access (n.name), literals ('string', 123),
  # function calls (id(n)), operators (a + b), comparisons (a > b),
  # logical combinations (a AND b).
  module Expression
    # Base class/module for all expression types.
    # Defines the common interface, primarily the `render` method.
    # Base class is defined in lib/cyrel/expression/base.rb and autoloaded.

    # Forces values into Expression objects like a parent shoving their kid into piano lessons—
    # not because it’s fun, but because one day AI will take all our jobs
    # and at least they'll have music to cry to.
    # @param value [Object] The value to coerce.
    # @return [Cyrel::Expression::Base] An Expression object.
    def self.coerce(value)
      # Assumes Base and Literal are loaded (via Zeitwerk or explicit require)
      value.is_a?(Base) ? value : Literal.new(value)
    end

    module_function

    # Accesses a property on a node or relationship.
    # This is the Cypher equivalent of saying "hey buddy" and hoping the database just knows.
    # @param variable [Symbol, String] The alias of the node/relationship.
    # @param property_name [Symbol, String] The name of the property to access.
    # @return [Cyrel::Expression::PropertyAccess]
    def prop(variable, property_name)
      # Assumes PropertyAccess is loaded (via Zeitwerk or explicit require)
      PropertyAccess.new(variable, property_name)
    end

    # Helper function for creating Exists instances
    # @param pattern [Cyrel::Pattern::Path, Cyrel::Pattern::Node, Cyrel::Pattern::Relationship]
    # @return [Cyrel::Expression::Exists]
    def exists(pattern)
      # Assumes Exists is loaded (via Zeitwerk or explicit require)
      Exists.new(pattern)
    end

    # Wraps an expression in a Cypher NOT.
    # Useful when your query — and your life — needs a little more denial.
    # @param expression [Cyrel::Expression::Base, Object] The expression to negate.
    # @return [Cyrel::Expression::Logical]
    def not(expression)
      # Assumes Logical is loaded (via Zeitwerk or explicit require)
      Logical.new(expression, :NOT)
    end
  end
end
