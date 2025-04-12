# frozen_string_literal: true

module Cyrel
  module Pattern
    # Represents a relationship pattern in a Cypher query,
    # e.g., -[alias:TYPE*1..n {prop: $param}]->.
    class Relationship
      attr_reader :alias_name, :types, :properties, :direction, :length

      # @param alias_name [Symbol, String, nil] The alias for the relationship.
      # @param types [Array<Symbol, String>, Symbol, String] The type(s) of the relationship.
      # @param properties [Hash] The properties to match or set on the relationship.
      # @param direction [Symbol] The direction (:outgoing, :incoming, :both).
      # @param length [String, Range, Integer, nil] The variable length specifier (e.g., '*1..5', 2).
      def initialize(alias_name: nil, types: [], properties: {}, direction: :outgoing, length: nil)
        @alias_name = alias_name&.to_sym
        @types = Array(types).map(&:to_s) # Ensure types are strings
        @properties = properties
        @direction = direction
        @length = format_length(length)
      end

      # Renders the relationship pattern part of the Cypher query.
      # @param query [Cyrel::Query] The query object, used for parameter registration.
      # @return [String] The Cypher string fragment for the relationship pattern.
      def render(query)
        # Build content parts carefully to manage spacing
        alias_part = @alias_name ? @alias_name.to_s : ''
        types_part = @types.empty? ? '' : ":#{@types.join('|')}"
        length_part = @length || '' # Already includes '*' if needed
        props_part = ''
        if @properties.any?
          prop_strings = @properties.map do |key, value|
            param_key = query.register_parameter(value)
            "#{key}: $#{param_key}"
          end
          props_part = " {#{prop_strings.join(', ')}}" # Prepend space
        end

        # Combine parts: alias, types, length (no space between type/length), properties
        core_parts = []
        core_parts << alias_part unless alias_part.empty?
        # Combine type and length directly
        core_parts << "#{types_part}#{length_part}" unless types_part.empty? && length_part.empty?

        content_core = core_parts.join(' ')
        content = "[#{content_core}#{props_part}]"
        # Apply direction arrows
        case @direction
        when :outgoing
          "-#{content}->"
        when :incoming
          "<-#{content}-"
        when :both
          "-#{content}-"
        else
          raise ArgumentError, "Invalid direction: #{@direction}"
        end
      end

      private

      # Formats the length specifier for Cypher.
      def format_length(len)
        case len
        when nil
          nil
        when Integer
          "*#{len}"
        when Range
          min = len.begin
          max = len.end
          exclude_end = len.exclude_end?
          max = exclude_end ? (max - 1) : max if max # Adjust max if range excludes end
          min_str = min || ''
          max_str = max || ''
          "*#{min_str}..#{max_str}"
        when String
          len # Assume it's already formatted correctly
        else
          raise ArgumentError, "Unsupported length type: #{len.class}"
        end
      end
    end
  end
end
