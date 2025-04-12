# frozen_string_literal: true

require_relative 'abstract_adapter'
require 'logger'

module ActiveCypher
  module ConnectionAdapters
    # A mock adapter for testing ActiveCypher without a real database connection.
    # It logs method calls and provides basic stubs.
    class MockAdapter < AbstractAdapter
      attr_reader :logged_queries

      def initialize(config)
        super
        @connected = false
        @in_transaction = false
        @logger = Logger.new($stdout) # Log to standard output for visibility
        @logger.level = Logger::INFO
        @logged_queries = []
        @logger.info "[MockAdapter] Initialized with config: #{config.inspect}"
      end

      def connect
        @logger.info '[MockAdapter] connect called'
        @connected = true
        true
      end

      def disconnect
        @logger.info '[MockAdapter] disconnect called'
        @connected = false
        true
      end

      def active?
        @logger.info "[MockAdapter] active? called, returning #{@connected}"
        @connected
      end

      def execute_cypher(cypher, params = {}, context = 'Query')
        @logger.info "[MockAdapter] execute_cypher called (Context: #{context})"
        @logger.info "  Cypher: #{cypher}"
        @logger.info "  Params: #{params.inspect}"
        @logged_queries << { cypher: cypher, params: params, context: context }

        # Return a predictable, empty result structure for basic testing.
        # Adapt this as needed for more complex mock scenarios.
        [] # e.g., an empty array representing no records found
      end

      def begin_transaction
        @logger.info '[MockAdapter] begin_transaction called'
        @logger.warn '[MockAdapter] Warning: Already in transaction' if @in_transaction
        @in_transaction = true
        # Return a mock transaction object/identifier
        "mock_tx_#{SecureRandom.hex(4)}"
      end

      def commit_transaction(transaction)
        @logger.info "[MockAdapter] commit_transaction called for #{transaction}"
        @logger.warn '[MockAdapter] Warning: Commit called outside of transaction' unless @in_transaction
        @in_transaction = false
      end

      def rollback_transaction(transaction)
        @logger.info "[MockAdapter] rollback_transaction called for #{transaction}"
        @logger.warn '[MockAdapter] Warning: Rollback called outside of transaction' unless @in_transaction
        @in_transaction = false
      end

      # Helper for tests to clear logged queries
      def clear_logs!
        @logged_queries = []
      end

      private

      attr_reader :logger
    end
  end
end

# Add SecureRandom require if not already available globally
require 'securerandom' unless defined?(SecureRandom)
