# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a DELETE or DETACH DELETE clause in a Cypher query.
    class Delete < Base
      attr_reader :variables, :detach

      # Initializes a DELETE clause.
      # @param variables [Array<Symbol, String>] An array of variable names (aliases) to delete.
      # @param detach [Boolean] Whether to use DETACH DELETE.
      def initialize(*variables, detach: false)
        @variables = variables.flatten.map(&:to_sym)
        @detach = detach
        raise ArgumentError, 'DELETE clause requires at least one variable.' if @variables.empty?
      end

      # Renders the DELETE or DETACH DELETE clause.
      # @param _query [Cyrel::Query] The query object (unused for DELETE).
      # @return [String] The Cypher string fragment for the clause.
      def render(_query)
        keyword = @detach ? 'DETACH DELETE' : 'DELETE'
        variable_list = @variables.join(', ')
        "#{keyword} #{variable_list}"
      end

      # Merges variables from another Delete clause.
      # Note: Merging DETACH and non-DETACH might require specific rules.
      # This implementation simply combines variables and uses the `detach`
      # status of the clause being merged into. A more robust implementation
      # might raise an error or prioritize DETACH if either is true.
      # @param other_delete [Cyrel::Clause::Delete] The other Delete clause to merge.
      def merge!(other_delete)
        @variables.concat(other_delete.variables).uniq!
        # Decide on detach status - let's prioritize detach=true if either has it
        @detach ||= other_delete.detach
        self
      end
    end
  end
end
