# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a MATCH or OPTIONAL MATCH clause in a Cypher query.
    class Match < Base
      attr_reader :pattern, :optional, :path_variable

      # @param pattern [Cyrel::Pattern::Path, Cyrel::Pattern::Node, Cyrel::Pattern::Relationship]
      #   The pattern to match. Typically a Path, but could be a single Node for simple matches.
      # @param optional [Boolean] Whether this is an OPTIONAL MATCH.
      # @param path_variable [Symbol, String, nil] An optional variable to assign to the matched path.
      def initialize(pattern, optional: false, path_variable: nil)
        super() # Call super for Base initialization
        # Ensure pattern is a valid type
        unless pattern.is_a?(Cyrel::Pattern::Path) ||
               pattern.is_a?(Cyrel::Pattern::Node) ||
               pattern.is_a?(Cyrel::Pattern::Relationship)
          raise ArgumentError,
                "Match pattern must be a Cyrel::Pattern::Path, Node, or Relationship, got #{pattern.class}"
        end

        @pattern = pattern
        @optional = optional
        @path_variable = path_variable&.to_sym
      end

      # Renders the MATCH or OPTIONAL MATCH clause.
      # @param query [Cyrel::Query] The query object for rendering the pattern.
      # @return [String] The Cypher string fragment for the clause.
      def render(query)
        keyword = @optional ? 'OPTIONAL MATCH' : 'MATCH'
        path_assignment = @path_variable ? "#{@path_variable} = " : ''
        pattern_string = @pattern.render(query)

        "#{keyword} #{path_assignment}#{pattern_string}"
      end
    end
  end
end
