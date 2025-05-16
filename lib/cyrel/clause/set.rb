# frozen_string_literal: true

require 'cyrel/expression'
require 'cyrel/expression/property_access'

module Cyrel
  module Clause
    # Represents a SET clause in a Cypher query.
    # Used for setting properties or labels on nodes/relationships.
    class Set < Base
      attr_reader :assignments

      # Initializes a SET clause.
      # @param assignments [Hash, Array]
      #   - Hash: { variable_or_prop_access => value_expression, ... }
      #     e.g., { Cyrel.prop(:n, :name) => "New Name", Cyrel.prop(:r, :weight) => 10 }
      #     e.g., { n: { name: "New Name", age: 30 } } # For SET n = properties or n += properties
      #     e.g., { Cyrel.plus(:n) => { name: "New Name" } } # For SET n += { name: ... }
      #   - Array: [[variable, label_string], ...] # For SET n:Label
      #     e.g., [[:n, "NewLabel"], [:m, "AnotherLabel"]]
      #   Note: Mixing hash and array styles in one call is not directly supported, use multiple SET clauses if needed.
      def initialize(assignments)
        @assignments = process_assignments(assignments)
      end

      # Renders the SET clause.
      # @param query [Cyrel::Query] The query object for rendering expressions.
      # @return [String, nil] The Cypher string fragment, or nil if no assignments exist.
      def render(query)
        return nil if @assignments.empty?

        set_parts = @assignments.map do |assignment|
          render_assignment(assignment, query)
        end

        "SET #{set_parts.join(', ')}"
      end

      # Merges assignments from another Set clause.
      # @param other_set [Cyrel::Clause::Set] The other Set clause to merge.
      def merge!(other_set)
        # Simple concatenation, assumes no conflicting assignments on the same property.
        # More sophisticated merging might be needed depending on requirements.
        @assignments.concat(other_set.assignments)
        self
      end

      private

      def process_assignments(assignments)
        case assignments
        when Hash
          assignments.flat_map do |key, value|
            case key
            when Expression::PropertyAccess
              # SET n.prop = value
              [[:property, key, Expression.coerce(value)]]
            when Symbol, String
              # SET n = properties
              raise ArgumentError, 'Value for variable assignment must be a Hash (for SET n = {props})' unless value.is_a?(Hash)

              [[:variable_properties, key.to_sym, Expression.coerce(value), :assign]]
            when Cyrel::Plus
              # SET n += properties
              raise ArgumentError, 'Value for variable assignment must be a Hash (for SET n += {props})' unless value.is_a?(Hash)

              [[:variable_properties, key.variable.to_sym, Expression.coerce(value), :merge]]
            else
              raise ArgumentError, "Invalid key type in SET assignments hash: #{key.class}"
            end
          end
        when Array
          assignments.map do |item|
            unless item.is_a?(Array) && item.length == 2 && item[0].is_a?(Symbol) && item[1].is_a?(String)
              raise ArgumentError,
                    "Invalid label assignment format. Expected [[:variable, 'Label'], ...], got #{item.inspect}"
            end

            # SET n:Label
            [:label, item[0], item[1]]
          end
        else
          raise ArgumentError, "Invalid assignments type for SET clause: #{assignments.class}"
        end
      end

      def render_assignment(assignment, query)
        type, target, value, op = assignment
        case type
        when :property
          # target is PropertyAccess, value is Expression
          "#{target.render(query)} = #{value.render(query)}"
        when :variable_properties
          # target is variable symbol, value is Expression (Literal Hash)
          if op == :merge
            "#{target} += #{value.render(query)}"
          else
            "#{target} = #{value.render(query)}"
          end
        when :label
          # target is variable symbol, value is label string
          "#{target}:#{value}" # Labels are not parameterized
        end
      end
    end
  end
end
