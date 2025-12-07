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

    # Create a node property index.
    # @param label [Symbol, String] Node label
    # @param props [Array<Symbol>] Properties to index
    # @param unique [Boolean] Create unique index (Neo4j only)
    # @param if_not_exists [Boolean] Add IF NOT EXISTS clause (Neo4j only)
    # @param name [String] Index name (Neo4j only)
    # @param composite [Boolean] Create composite index (Memgraph 3.2+). Default true for multiple props.
    def create_node_index(label, *props, unique: false, if_not_exists: true, name: nil, composite: nil)
      # Default composite to true when multiple properties provided
      composite = props.size > 1 if composite.nil?

      cypher = if connection.vendor == :memgraph
                 if composite && props.size > 1
                   # Memgraph 3.2+ composite index: CREATE INDEX ON :Label(prop1, prop2)
                   props_list = props.join(', ')
                   ["CREATE INDEX ON :#{label}(#{props_list})"]
                 else
                   # Memgraph single property indexes
                   props.map { |p| "CREATE INDEX ON :#{label}(#{p})" }
                 end
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

    # Create a relationship property index.
    # @param rel_type [Symbol, String] Relationship type
    # @param props [Array<Symbol>] Properties to index
    # @param if_not_exists [Boolean] Add IF NOT EXISTS clause (Neo4j only)
    # @param name [String] Index name (Neo4j only)
    # @param composite [Boolean] Create composite index (Memgraph 3.2+). Default true for multiple props.
    def create_rel_index(rel_type, *props, if_not_exists: true, name: nil, composite: nil)
      composite = props.size > 1 if composite.nil?

      cypher = if connection.vendor == :memgraph
                 if composite && props.size > 1
                   # Memgraph 3.2+ composite edge index
                   props_list = props.join(', ')
                   ["CREATE EDGE INDEX ON :#{rel_type}(#{props_list})"]
                 else
                   props.map { |p| "CREATE EDGE INDEX ON :#{rel_type}(#{p})" }
                 end
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

    # Create a vector index (Memgraph 3.4+, Neo4j 5.0+).
    # @param name [String] Index name
    # @param label [Symbol, String] Node label
    # @param property [Symbol] Property containing vector embeddings
    # @param dimension [Integer] Vector dimension (required)
    # @param metric [Symbol] Distance metric: :cosine, :euclidean, :dot_product (default: :cosine)
    # @param quantization [Symbol] Quantization type for memory reduction (Memgraph 3.4+): :scalar, nil
    def create_vector_index(name, label, property, dimension:, metric: :cosine, quantization: nil)
      cypher = if connection.vendor == :memgraph
                 config = { dimension: dimension, metric: metric.to_s }
                 config[:scalar_kind] = 'f32' if quantization == :scalar
                 config_str = config.map { |k, v| "#{k}: #{v.is_a?(String) ? "'#{v}'" : v}" }.join(', ')
                 "CREATE VECTOR INDEX #{name} ON :#{label}(#{property}) WITH CONFIG { #{config_str} }"
               else
                 # Neo4j syntax
                 options = { indexConfig: { 'vector.dimensions' => dimension, 'vector.similarity_function' => metric.to_s.upcase } }
                 opts_str = options.to_json.gsub('"', "'")
                 "CREATE VECTOR INDEX #{name} IF NOT EXISTS FOR (n:#{label}) ON (n.#{property}) OPTIONS #{opts_str}"
               end
      operations << cypher
    end

    # Create a vector index on relationships (Memgraph 3.4+, Neo4j 2025+).
    # @param name [String] Index name
    # @param rel_type [Symbol, String] Relationship type
    # @param property [Symbol] Property containing vector embeddings
    # @param dimension [Integer] Vector dimension (required)
    # @param metric [Symbol] Distance metric: :cosine, :euclidean, :dot_product (default: :cosine)
    def create_vector_rel_index(name, rel_type, property, dimension:, metric: :cosine)
      cypher = if connection.vendor == :memgraph
                 config_str = "dimension: #{dimension}, metric: '#{metric}'"
                 "CREATE VECTOR EDGE INDEX #{name} ON :#{rel_type}(#{property}) WITH CONFIG { #{config_str} }"
               else
                 # Neo4j 2025+ syntax
                 "CREATE VECTOR INDEX #{name} IF NOT EXISTS FOR ()-[r:#{rel_type}]-() ON (r.#{property}) " \
                   "OPTIONS { indexConfig: { `vector.dimensions`: #{dimension}, `vector.similarity_function`: '#{metric}' } }"
               end
      operations << cypher
    end

    # Alias for backwards compatibility
    alias create_vector_edge_index create_vector_rel_index

    # Create a text index on edges (Memgraph 3.6+ only).
    # Neo4j fulltext indexes on relationships use different syntax via create_fulltext_rel_index.
    # @param name [String] Index name
    # @param rel_type [Symbol, String] Relationship type
    # @param props [Array<Symbol>] Properties to index
    def create_text_edge_index(name, rel_type, *props)
      raise NotImplementedError, 'Text edge indexes only supported on Memgraph 3.6+' unless connection.vendor == :memgraph

      props.each do |p|
        index_name = props.size > 1 ? "#{name}_#{p}" : name.to_s
        operations << "CREATE TEXT EDGE INDEX #{index_name} ON :#{rel_type}(#{p})"
      end
    end

    # Create a fulltext index on relationships (Neo4j only).
    # @param name [String] Index name
    # @param rel_type [Symbol, String] Relationship type
    # @param props [Array<Symbol>] Properties to index
    # @param if_not_exists [Boolean] Add IF NOT EXISTS clause
    def create_fulltext_rel_index(name, rel_type, *props, if_not_exists: true)
      raise NotImplementedError, 'Fulltext relationship indexes only supported on Neo4j' unless connection.vendor == :neo4j

      props_clause = props.map { |p| "r.#{p}" }.join(', ')
      c = +"CREATE FULLTEXT INDEX #{name}"
      c << ' IF NOT EXISTS' if if_not_exists
      c << " FOR ()-[r:#{rel_type}]-() ON EACH [#{props_clause}]"
      operations << c
    end

    # Drop all indexes (Memgraph 3.6+ only).
    # Neo4j requires dropping indexes individually.
    def drop_all_indexes
      raise NotImplementedError, 'drop_all_indexes only supported on Memgraph 3.6+' unless connection.vendor == :memgraph

      operations << 'DROP ALL INDEXES'
    end

    # Drop all constraints (Memgraph 3.6+ only).
    # Neo4j requires dropping constraints individually.
    def drop_all_constraints
      raise NotImplementedError, 'drop_all_constraints only supported on Memgraph 3.6+' unless connection.vendor == :memgraph

      operations << 'DROP ALL CONSTRAINTS'
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
