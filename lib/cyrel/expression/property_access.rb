# frozen_string_literal: true

require_relative 'base'

module Cyrel
  module Expression
    # Represents accessing a property on a variable (node or relationship alias).
    # Example: n.name, r.since
    class PropertyAccess < Base
      attr_reader :variable, :property_name

      # @param variable [Symbol, String] The alias of the node/relationship.
      # @param property_name [Symbol, String] The name of the property to access.
      def initialize(variable, property_name)
        @variable = variable.to_sym
        @property_name = property_name.to_sym
      end

      # Renders the property access expression.
      # @param _query [Cyrel::Query] The query object (unused for simple property access).
      # @return [String] The Cypher string fragment (e.g., "n.name").
      def render(_query)
        "#{@variable}.#{@property_name}"
      end
    end
  end
end
