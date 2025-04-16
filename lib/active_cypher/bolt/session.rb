# frozen_string_literal: true

require 'async'

module ActiveCypher
  module Bolt
    # A Session is the primary unit of work in the Bolt Protocol.
    # It maintains a connection to the database server and allows running queries.
    class Session
      attr_reader :connection, :database

      def initialize(connection, database: nil)
        @connection = connection

        # For Memgraph, never set a database (they don't support multiple DBs)
        @database = if connection.adapter.is_a?(ConnectionAdapters::MemgraphAdapter)
                      nil
                    else
                      database
                    end

        @current_transaction = nil
        @bookmarks = []
      end

      # Executes a Cypher query and returns the result.
      #
      # @param query [String] The Cypher query to execute.
      # @param parameters [Hash] Parameters for the query.
      # @param mode [Symbol] The access mode (:read or :write).
      # @param db [String] The database name to run the query against.
      # @return [Result] The result of the query execution.
      def run(query, parameters = {}, mode: :write, db: nil)
        # For Memgraph, explicitly set db to nil
        db = nil if @connection.adapter.is_a?(ConnectionAdapters::MemgraphAdapter)

        if @current_transaction&.active?
          # If we have an active transaction, run the query within it
          @current_transaction.run(query, parameters)
        else
          # Auto-transaction mode: each query gets its own transaction
          run_transaction(mode, db: db) do |tx|
            tx.run(query, parameters)
          end
        end
      end

      # Begin a new transaction.
      #
      # @param db [String] The database name to begin the transaction against.
      # @param access_mode [Symbol] The access mode (:read or :write).
      # @param tx_timeout [Integer] Transaction timeout in milliseconds.
      # @param tx_metadata [Hash] Transaction metadata to send to the server.
      # @return [Transaction] The new transaction.
      def begin_transaction(db: nil, access_mode: :write, tx_timeout: nil, tx_metadata: nil)
        raise ConnectionError, 'Already in a transaction' if @current_transaction&.active?

        # Send BEGIN message with appropriate metadata
        begin_meta = {}
        # For Memgraph, NEVER set a database name - it doesn't support them
        if @connection.adapter.is_a?(ConnectionAdapters::MemgraphAdapter)
          # Explicitly don't set db for Memgraph
          begin_meta['adapter'] = 'memgraph'
          # Force db to nil for Memgraph
          nil
        elsif db || @database
          begin_meta['db'] = db || @database
        end
        begin_meta['mode'] = access_mode == :read ? 'r' : 'w'
        begin_meta['tx_timeout'] = tx_timeout if tx_timeout
        begin_meta['tx_metadata'] = tx_metadata if tx_metadata
        begin_meta['bookmarks'] = @bookmarks if @bookmarks&.any?

        begin_msg = Messaging::Begin.new(begin_meta)
        @connection.write_message(begin_msg)

        # Read response to BEGIN
        response = @connection.read_message

        case response
        when Messaging::Success
          # BEGIN succeeded, create a new transaction
          @current_transaction = Transaction.new(self, @bookmarks, response.metadata)
        when Messaging::Failure
          # BEGIN failed
          code = response.metadata['code']
          message = response.metadata['message']
          @connection.reset!
          raise QueryError, "Failed to begin transaction: #{code} - #{message}"
        else
          raise ProtocolError, "Unexpected response to BEGIN: #{response.class}"
        end
      end

      # Marks a transaction as completed and removes it from the session.
      #
      # @param transaction [Transaction] The transaction to complete.
      # @param new_bookmarks [Array<String>] New bookmarks to update.
      def complete_transaction(transaction, new_bookmarks = nil)
        return unless transaction == @current_transaction

        @current_transaction = nil
        @bookmarks = new_bookmarks if new_bookmarks
      end

      # Execute a block of code within a transaction.
      #
      # @param mode [Symbol] The access mode (:read or :write).
      # @param db [String] The database name to run the transaction against.
      # @param timeout [Integer] Transaction timeout in milliseconds.
      # @param metadata [Hash] Transaction metadata to send to the server.
      # @yield [tx] The transaction to use for queries.
      # @return The result of the block.
      def run_transaction(mode = :write, db: nil, timeout: nil, metadata: nil, &)
        # Ensure we're running in an Async context
        if Async::Task.current?
          # Already in an Async task, proceed normally
          begin
            execute_transaction(mode, db: db, timeout: timeout, metadata: metadata, &)
          rescue StandardError => e
            # Ensure errors are properly propagated
            raise e
          end
        else
          # Wrap in an Async task
          result = nil
          error = nil

          Async do
            result = execute_transaction(mode, db: db, timeout: timeout, metadata: metadata, &)
          rescue StandardError => e
            error = e
          end.wait

          # Re-raise any error outside the async block
          raise error if error

          result
        end
      end

      # Helper method to execute the transaction
      def execute_transaction(mode, db:, timeout:, metadata:)
        tx = begin_transaction(db: db,
                               access_mode: mode,
                               tx_timeout: timeout,
                               tx_metadata: metadata)

        result = yield tx           # your block runs here
        tx.commit                   # happy path
        result
      rescue StandardError => e     # any error → rollback → wrap
        begin
          tx.rollback
        rescue StandardError => rollback_error
          # Log rollback error but continue with the original error
          puts "Error during rollback: #{rollback_error.message}" if ENV['DEBUG']
        end

        # Preserve the original error
        raise ActiveCypher::TransactionError, e.message
      end

      def write_transaction(db: nil, timeout: nil, metadata: nil, &)
        run_transaction(:write, db: db, timeout: timeout, metadata: metadata, &)
      end

      def read_transaction(db: nil, timeout: nil, metadata: nil, &)
        run_transaction(:read, db: db, timeout: timeout, metadata: metadata, &)
      end

      # Access the current bookmarks for this session.
      def bookmarks
        @bookmarks || []
      end

      # Update session bookmarks for causal consistency.
      attr_writer :bookmarks

      # Reset any session and transaction state (e.g., after errors).
      def reset
        return if @current_transaction.nil?

        # Mark the current transaction as no longer active
        complete_transaction(@current_transaction)

        # Reset the connection
        @connection.reset!
      end

      # Close the session and any active transaction.
      def close
        # If there's an active transaction, try to roll it back
        @current_transaction&.rollback if @current_transaction&.active?

        # Mark current transaction as complete
        complete_transaction(@current_transaction) if @current_transaction
      end
    end
  end
end
