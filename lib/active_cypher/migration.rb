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
      cypher = if connection.vendor == :memgraph
                 # Memgraph syntax: CREATE INDEX ON :Label(prop)
                 props.map { |p| "CREATE INDEX ON :#{label}(#{p})" }
               else
                 # Neo4j syntax
                 props_clause = props.map { |p| "n.#{p}" }.join(', ')
                 c = +'CREATE '
                 c << 'UNIQUE ' if unique
                 c << 'INDEX'
                 c << " #{name}" if name
                 c << ' IF NOT EXISTS' if if_not_exists
                 c << " FOR (n:#{label}) ON (#{props_clause})"
                 [c]
               end
      operations.concat(Array(cypher))
    end

    def create_rel_index(rel_type, *props, if_not_exists: true, name: nil)
      cypher = if connection.vendor == :memgraph
                 # Memgraph syntax: CREATE EDGE INDEX ON :REL_TYPE(prop)
                 props.map { |p| "CREATE EDGE INDEX ON :#{rel_type}(#{p})" }
               else
                 # Neo4j syntax
                 props_clause = props.map { |p| "r.#{p}" }.join(', ')
                 c = +'CREATE INDEX'
                 c << " #{name}" if name
                 c << ' IF NOT EXISTS' if if_not_exists
                 c << " FOR ()-[r:#{rel_type}]-() ON (#{props_clause})"
                 [c]
               end
      operations.concat(Array(cypher))
    end

    def create_uniqueness_constraint(label, *props, if_not_exists: true, name: nil)
      cypher = if connection.vendor == :memgraph
                 # Memgraph syntax: CREATE CONSTRAINT ON (n:Label) ASSERT n.prop IS UNIQUE
                 # Note: Memgraph doesn't support IF NOT EXISTS or named constraints
                 props_clause = props.map { |p| "n.#{p}" }.join(', ')
                 "CREATE CONSTRAINT ON (n:#{label}) ASSERT #{props_clause} IS UNIQUE"
               else
                 # Neo4j syntax
                 props_clause = props.map { |p| "n.#{p}" }.join(', ')
                 c = +'CREATE CONSTRAINT'
                 c << " #{name}" if name
                 c << ' IF NOT EXISTS' if if_not_exists
                 c << " FOR (n:#{label}) REQUIRE (#{props_clause}) IS UNIQUE"
                 c
               end
      operations << cypher
    end

    def create_fulltext_index(name, label, *props, if_not_exists: true)
      cypher = if connection.vendor == :memgraph
                 # Memgraph TEXT INDEX syntax (requires --experimental-enabled='text-search')
                 # Memgraph only supports single property per text index, so create one per prop
                 props.map.with_index do |p, i|
                   index_name = props.size > 1 ? "#{name}_#{p}" : name.to_s
                   "CREATE TEXT INDEX #{index_name} ON :#{label}(#{p})"
                 end
               else
                 # Neo4j syntax
                 props_clause = props.map { |p| "n.#{p}" }.join(', ')
                 c = +"CREATE FULLTEXT INDEX #{name}"
                 c << ' IF NOT EXISTS' if if_not_exists
                 c << " FOR (n:#{label}) ON EACH [#{props_clause}]"
                 [c]
               end
      operations.concat(Array(cypher))
    end

    def execute(cypher_string)
      operations << cypher_string.strip
    end

    private

    def execute_operations
      if connection.vendor == :memgraph
        # Memgraph requires auto-commit for DDL operations
        operations.each { |cypher| connection.execute_ddl(cypher) }
      else
        # Run each DDL individually (implicit auto-commit) to avoid session/async issues
        operations.each { |cypher| connection.execute_cypher(cypher) }
      end
    rescue StandardError
      # Memgraph DDL is auto-committed, no rollback possible
      raise
    end
  end
end
