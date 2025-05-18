# frozen_string_literal: true

module ActiveCypher
  module Bolt
    # Manages transaction state (BEGIN/COMMIT/ROLLBACK) and runs queries within a transaction.
    class Transaction
      include Instrumentation
      attr_reader :bookmarks, :metadata, :connection

      # Initializes a new Transaction instance.
      #
      # @param session [Session] The session that owns this transaction.
      # @param initial_bookmarks [Array<String>] Initial bookmarks for causal consistency.
      # @param metadata [Hash] Metadata from the BEGIN success response.
      def initialize(session, initial_bookmarks, metadata = {})
        @session = session
        @connection = session.connection
        @bookmarks = initial_bookmarks || []
        @metadata = metadata
        @state = :active
      end

      # Runs a Cypher query within this transaction.
      #
      # @param query [String] The Cypher query to execute.
      # @param parameters [Hash] Parameters for the query.
      # @return [Result] The result of the query execution.
      def run(query, parameters = {})
        raise ConnectionError, "Cannot run query on a #{@state} transaction" unless @state == :active

        # Ensure query is a string
        query_str = query.is_a?(String) ? query : query.to_s

        instrument_query(query_str, parameters, context: 'Transaction#run', metadata: { transaction_id: object_id }) do
          # Send RUN message
          run_metadata = {}
          run_msg = Messaging::Run.new(query_str, parameters, run_metadata)
          connection.write_message(run_msg)

          # Read response to RUN
          response = connection.read_message
          qid = -1
          fields = []

          case response
          when Messaging::Success
            # RUN succeeded, extract metadata

            qid = response.metadata['qid'] if response.metadata.key?('qid')
            fields = response.metadata['fields'] if response.metadata.key?('fields')

            # Send PULL to get all records (-1 = all)
            pull_metadata = { 'n' => -1 }
            pull_metadata['qid'] = qid if qid != -1
            pull_msg = Messaging::Pull.new(pull_metadata)
            connection.write_message(pull_msg)

            # Process PULL response(s)
            records = []
            summary_metadata = {}

            # Read messages until we get a SUCCESS (or FAILURE)
            loop do
              msg = connection.read_message
              case msg
              when Messaging::Record
                # Store record with raw values - processing will happen in the adapter
                records << msg.values
              when Messaging::Success
                # Final SUCCESS with summary metadata
                summary_metadata = msg.metadata
                break # Done processing results
              when Messaging::Failure
                connection.reset!
                # PULL failed - transaction is now failed
                @state = :failed
                code = msg.metadata['code']
                message = msg.metadata['message']
                raise QueryError, "Query execution failed: #{code} - #{message}"
              else
                raise ProtocolError, "Unexpected message type: #{msg.class}"
              end
            end

            # Create and return Result object
            Result.new(fields, records, summary_metadata, qid)
          when Messaging::Failure
            # RUN failed - transaction is now failed
            @state = :failed
            code = response.metadata['code']
            message = response.metadata['message']
            raise QueryError, "Query execution failed: #{code} - #{message}"
          else
            raise ProtocolError, "Unexpected response to RUN: #{response.class}"
          end
        end
      rescue ConnectionError
        @state = :failed
        raise
      end

      # Commits the transaction.
      #
      # @return [Array<String>] Any new bookmarks.
      def commit
        raise ConnectionError, "Cannot commit a #{@state} transaction" unless @state == :active

        instrument_transaction(:commit, object_id) do
          # Send COMMIT message
          commit_msg = Messaging::Commit.new
          connection.write_message(commit_msg)

          # Read response to COMMIT
          response = connection.read_message

          case response
          when Messaging::Success
            # COMMIT succeeded

            @state = :committed

            # Extract bookmarks if any
            new_bookmarks = []
            if response.metadata.key?('bookmark')
              new_bookmarks = [response.metadata['bookmark']]
              @bookmarks = new_bookmarks
            end

            # Mark transaction as completed in the session
            @session.complete_transaction(self, new_bookmarks)

            new_bookmarks
          when Messaging::Failure
            # COMMIT failed
            @state = :failed
            code = response.metadata['code']
            message = response.metadata['message']

            # Mark transaction as completed in the session
            @session.complete_transaction(self)

            raise QueryError, "Failed to commit transaction: #{code} - #{message}"
          else
            raise ProtocolError, "Unexpected response to COMMIT: #{response.class}"
          end
        end
      rescue ConnectionError
        @state = :failed
        # Mark transaction as completed in the session
        begin
          @session.complete_transaction(self)
        rescue StandardError
          nil
        end
        raise
      end

      # Rolls back the transaction.
      def rollback
        # If already committed or rolled back, do nothing
        return if @state == :committed || @state == :rolled_back

        instrument_transaction(:rollback, object_id) do
          # Send ROLLBACK message
          rollback_msg = Messaging::Rollback.new
          connection.write_message(rollback_msg)

          # Read response to ROLLBACK
          response = connection.read_message

          case response
          when Messaging::Success
            # ROLLBACK succeeded

          when Messaging::Failure
            # ROLLBACK failed - unusual but possible if connection is in a bad state
            response.metadata['code']
            response.metadata['message']

            # We don't raise here to ensure the rollback doesn't throw exceptions
          end
        rescue StandardError
          # We catch all exceptions during rollback to ensure it doesn't throw
        ensure
          # Always mark as rolled back and complete the transaction
          @state = :rolled_back
          begin
            @session.complete_transaction(self)
          rescue StandardError
            nil
          end
        end
      end

      # Checks if the transaction is active.
      def active?
        @state == :active
      end

      # Checks if the transaction is committed.
      def committed?
        @state == :committed
      end

      # Checks if the transaction is rolled back.
      def rolled_back?
        @state == :rolled_back
      end

      # Checks if the transaction is in a failed state.
      def failed?
        @state == :failed
      end
    end
  end
end
