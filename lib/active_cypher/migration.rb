# frozen_string_literal: true

module ActiveCypher
  # Base class for GraphDB migrations.
  # Provides a small DSL for defining index and constraint operations.
  class Migration
    class << self
      attr_reader :up_block

      # Define the migration steps.
      def up(&block)
        @up_block = block if block_given?
      end
    end

    attr_reader :connection, :operations

    def initialize(connection = ActiveCypher::Base.connection)
      @connection = connection
      @operations = []
    end

    # Execute the migration.
    def run
      instance_eval(&self.class.up_block) if self.class.up_block
      execute_operations
    end

    # DSL ---------------------------------------------------------------

    def create_node_index(label, *props, unique: false, if_not_exists: true, name: nil)
      props_clause = props.map { |p| "n.#{p}" }.join(', ')
      cypher = +'CREATE '
      cypher << 'UNIQUE ' if unique
      cypher << 'INDEX'
      cypher << " #{name}" if name
      cypher << ' IF NOT EXISTS' if if_not_exists
      cypher << " FOR (n:#{label}) ON (#{props_clause})"
      operations << cypher
    end

    def create_rel_index(rel_type, *props, if_not_exists: true, name: nil)
      props_clause = props.map { |p| "r.#{p}" }.join(', ')
      cypher = +'CREATE INDEX'
      cypher << " #{name}" if name
      cypher << ' IF NOT EXISTS' if if_not_exists
      cypher << " FOR ()-[r:#{rel_type}]-() ON (#{props_clause})"
      operations << cypher
    end

    def create_uniqueness_constraint(label, *props, if_not_exists: true, name: nil)
      props_clause = props.map { |p| "n.#{p}" }.join(', ')
      cypher = +'CREATE CONSTRAINT'
      cypher << " #{name}" if name
      cypher << ' IF NOT EXISTS' if if_not_exists
      cypher << " FOR (n:#{label}) REQUIRE (#{props_clause}) IS UNIQUE"
      operations << cypher
    end

    def execute(cypher_string)
      operations << cypher_string.strip
    end

    private

    def execute_operations
      tx = connection.begin_transaction if connection.respond_to?(:begin_transaction)
      operations.each do |cypher|
        if tx
          tx.run(cypher)
        else
          connection.execute_cypher(cypher)
        end
      end
      connection.commit_transaction(tx) if tx
    rescue StandardError
      connection.rollback_transaction(tx) if tx
      raise
    end
  end
end
