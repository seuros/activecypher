# frozen_string_literal: true

module ActiveCypher
  module ConnectionAdapters
    # Defines the abstract interface for ActiveCypher connection adapters.
    # Concrete adapters for specific graph databases (like Neo4j, Memgraph)
    # must inherit from this class and implement its methods.
    class AbstractAdapter
      def initialize(config)
        @config = config
        # Optional: Establish connection immediately or defer
        # connect
      end

      # Establishes the connection to the database.
      # Should be idempotent.
      # @return [Boolean] true if connection is successful or already established.
      def connect
        raise NotImplementedError, "#{self.class.name}#connect must be implemented"
      end

      # Disconnects from the database.
      # Should be idempotent.
      # @return [Boolean] true if disconnection is successful or already disconnected.
      def disconnect
        raise NotImplementedError, "#{self.class.name}#disconnect must be implemented"
      end

      # Checks if the connection to the database is active.
      # @return [Boolean] true if the connection is active, false otherwise.
      def active?
        raise NotImplementedError, "#{self.class.name}#active? must be implemented"
      end

      # Executes a Cypher query.
      # @param cypher [String] The Cypher query string to execute.
      # @param params [Hash] Optional parameters to bind to the query.
      # @param context [String] Optional context for logging (e.g., "Load", "Save").
      # @return [Object] The raw result from the database driver, format depends on the driver.
      #         The calling code (e.g., Relation) is responsible for mapping this raw result.
      def execute_cypher(cypher, params = {}, context = 'Query')
        raise NotImplementedError, "#{self.class.name}#execute_cypher must be implemented"
      end

      # Begins a transaction.
      # @return [Object] Transaction object or identifier, depending on the driver.
      def begin_transaction
        raise NotImplementedError, "#{self.class.name}#begin_transaction must be implemented"
      end

      # Commits the current transaction.
      # @param transaction [Object] The transaction object/identifier returned by begin_transaction.
      def commit_transaction(transaction)
        raise NotImplementedError, "#{self.class.name}#commit_transaction must be implemented"
      end

      # Rolls back the current transaction.
      # @param transaction [Object] The transaction object/identifier returned by begin_transaction.
      def rollback_transaction(transaction)
        raise NotImplementedError, "#{self.class.name}#rollback_transaction must be implemented"
      end

      # Optional: Methods for schema management (e.g., creating constraints/indexes)
      # def create_constraint(...)
      # def drop_constraint(...)

      private

      attr_reader :config
    end
  end
end
