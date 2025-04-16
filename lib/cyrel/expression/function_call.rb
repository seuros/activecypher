# frozen_string_literal: true

module Cyrel
  module Expression
    # Represents a function call in Cypher (e.g., id(n), count(*), coalesce(a, b)).
    class FunctionCall < Base
      attr_reader :function_name, :arguments, :distinct

      # @param function_name [Symbol, String] The name of the Cypher function.
      # @param arguments [Array<Cyrel::Expression::Base, Object>] The arguments to the function.
      # @param distinct [Boolean] Whether to use the DISTINCT keyword (e.g., count(DISTINCT n)).
      def initialize(function_name, arguments = [], distinct: false)
        @function_name = function_name.to_s # Store as string for consistency
        @arguments = Array(arguments).map do |arg|
          # Don't coerce ASTERISK or existing Expressions
          if arg == Functions::ASTERISK || arg.is_a?(Expression::Base)
            arg
          else
            Expression.coerce(arg) # Coerce only non-expression literals
          end
        end
        @distinct = distinct
      end

      # Renders the function call expression.
      # @param query [Cyrel::Query] The query object for rendering arguments.
      # @return [String] The Cypher string fragment (e.g., "id(n)", "count(DISTINCT n.prop)").
      def render(query)
        rendered_args = @arguments.map do |arg|
          case arg
          when Functions::ASTERISK
            '*'
          # Special handling for RawIdentifier when used as argument
          when Clause::Return::RawIdentifier
            arg.identifier # Render the raw identifier directly
          when Expression::Base, ->(a) { a.respond_to?(:render) } # Check if it's an Expression or renderable
            arg.render(query) # Render other expressions normally
          else
            # Parameterize other literal values
            param_key = query.register_parameter(arg)
            "$#{param_key}"
          end
        end.join(', ')
        distinct_str = @distinct ? 'DISTINCT ' : ''
        "#{@function_name}(#{distinct_str}#{rendered_args})"
      end

      # Creates an aliased version of this function call expression.
      # Duplicates method from Base for robustness.
      # @param alias_name [Symbol, String] The alias to assign.
      # @return [Cyrel::Expression::Alias]
      def as(alias_name)
        Alias.new(self, alias_name)
      end
    end
  end
end
