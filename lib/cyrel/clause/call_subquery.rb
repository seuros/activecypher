# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a CALL { subquery } clause.
    class CallSubquery < Base
      attr_reader :subquery

      # @param subquery [Cyrel::Query] The nested query object.
      def initialize(subquery)
        super() # Call super for Base initialization
        unless subquery.is_a?(Cyrel::Query)
          raise ArgumentError, "Subquery must be a Cyrel::Query instance, got #{subquery.class}"
        end

        @subquery = subquery
      end

      # Renders the CALL { subquery } clause.
      # Note: Parameter merging between outer and inner queries needs careful handling.
      # This basic implementation assumes parameters are managed separately or
      # the outer query's #merge! handles parameter transfer if the subquery
      # was built and then passed in.
      # @param _outer_query [Cyrel::Query] The outer query object (potentially needed for parameter context).
      # @return [String] The Cypher string fragment for the clause.
      def render(_outer_query)
        # We need the subquery's cypher string and parameters.
        # Parameters from the subquery need to be merged into the outer query.
        # This is complex. For now, let's assume parameters are handled externally
        # or the subquery doesn't introduce new parameters conflicting with the outer scope.
        # A more robust solution would involve the outer query managing all parameters.

        sub_cypher, _sub_params = @subquery.to_cypher
        # Removed puts
        indented_sub_cypher = sub_cypher.gsub(/^/, '  ') # Indent subquery
        final_string = "CALL {\n#{indented_sub_cypher}\n}" # Construct final string
        # Removed puts
        final_string # Return final string
      end
    end
  end
end
