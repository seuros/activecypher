# frozen_string_literal: true

module ActiveCypher
  module Bolt
    # Handles query results, streams records, and provides summary information.
    # Represents the result of a Cypher query execution.
    class Result
      include Enumerable # Allows iteration over records

      attr_reader :fields, :summary_metadata, :qid

      # @param fields [Array<String>] List of field names in the result.
      # @param records [Array<Array>] List of records, where each record is a list of values.
      # @param summary_metadata [Hash] Metadata received in the final SUCCESS message.
      # @param qid [Integer, nil] The query ID associated with this result (-1 if none).
      def initialize(fields, records, summary_metadata, qid = -1)
        @fields = fields || [] # Ensure fields is an array
        @records = records
        @summary_metadata = summary_metadata || {}
        @qid = qid
        @consumed = false
        @record_index = 0
      end

      # Allows iterating over the records using `each`.
      # Yields each record as a Hash with field names as keys (symbols).
      def each
        raise 'Result already consumed or closed' if @consumed
        return enum_for(:each) unless block_given? # Return enumerator if no block

        @records.each do |record_values|
          yield @fields.map(&:to_sym).zip(record_values).to_h
        end
        consume # Mark as consumed after successful iteration
      end

      # Retrieves a single record. Raises error if no records or more than one.
      # @return [Hash] The single record as a symbol-keyed hash.
      # @raise [RuntimeError] If the number of records is not exactly one.
      def single
        raise 'Result already consumed or closed' if @consumed
        raise "Expected exactly one record, but found #{@records.size}" unless @records.size == 1

        record = @fields.map(&:to_sym).zip(@records.first).to_h
        consume
        record
      end

      # Retrieves all records as an array of hashes.
      # @return [Array<Hash>]
      def to_a
        raise 'Result already consumed or closed' if @consumed

        result_array = @records.map do |record_values|
          @fields.map(&:to_sym).zip(record_values).to_h
        end
        consume
        result_array
      end

      # Checks if the result stream is still open (i.e., not fully consumed).
      # @return [Boolean]
      def open?
        !@consumed
      end

      # Marks the result as fully consumed.
      def consume
        @consumed = true
        # Potentially release resources if streaming was implemented differently
      end

      # Provides summary information about the query execution.
      # @return [Hash] Summary metadata (e.g., counters, query type).
      def summary
        # TODO: Parse summary_metadata into a more structured Summary object?
        consume unless @consumed # Ensure result is consumed before accessing summary
        @summary_metadata
      end
    end
  end
end
