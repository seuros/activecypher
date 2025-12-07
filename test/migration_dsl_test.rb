# frozen_string_literal: true

require 'test_helper'

class MigrationDSLTest < ActiveSupport::TestCase
  class CaptureAdapter < ActiveCypher::ConnectionAdapters::AbstractAdapter
    attr_reader :executed
    attr_accessor :vendor_type

    def initialize(vendor_type = :neo4j)
      @executed = []
      @vendor_type = vendor_type
    end

    def vendor = @vendor_type

    def execute_cypher(cypher, _params = {}, _ctx = 'Query')
      @executed << cypher.strip
      []
    end

    def execute_ddl(cypher, _params = {})
      @executed << cypher.strip
      []
    end
  end

  test 'DSL methods generate expected cypher' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_node_index :Foo, :bar, name: :foo_bar_idx
        create_rel_index :BARREL, :kind
        create_uniqueness_constraint :Foo, :bar, name: :foo_bar_unique
        execute 'CREATE INDEX IF NOT EXISTS FOR (f:Foo) ON (f.created_at)'
      end
    end

    adapter = CaptureAdapter.new
    klass.new(adapter).run

    assert_equal [
      'CREATE INDEX foo_bar_idx IF NOT EXISTS FOR (n:Foo) ON (n.bar)',
      'CREATE INDEX IF NOT EXISTS FOR ()-[r:BARREL]-() ON (r.kind)',
      'CREATE CONSTRAINT foo_bar_unique IF NOT EXISTS FOR (n:Foo) REQUIRE (n.bar) IS UNIQUE',
      'CREATE INDEX IF NOT EXISTS FOR (f:Foo) ON (f.created_at)'
    ], adapter.executed
  end

  # --- Composite Index Tests (Memgraph 3.2+) ---

  test 'composite node index for Memgraph' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_node_index :Person, :name, :email
      end
    end

    adapter = CaptureAdapter.new(:memgraph)
    klass.new(adapter).run

    assert_equal ['CREATE INDEX ON :Person(name, email)'], adapter.executed
  end

  test 'composite node index explicit false creates separate indexes for Memgraph' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_node_index :Person, :name, :email, composite: false
      end
    end

    adapter = CaptureAdapter.new(:memgraph)
    klass.new(adapter).run

    assert_equal [
      'CREATE INDEX ON :Person(name)',
      'CREATE INDEX ON :Person(email)'
    ], adapter.executed
  end

  test 'single property index for Memgraph' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_node_index :Person, :name
      end
    end

    adapter = CaptureAdapter.new(:memgraph)
    klass.new(adapter).run

    assert_equal ['CREATE INDEX ON :Person(name)'], adapter.executed
  end

  test 'composite rel index for Memgraph' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_rel_index :KNOWS, :since, :strength
      end
    end

    adapter = CaptureAdapter.new(:memgraph)
    klass.new(adapter).run

    assert_equal ['CREATE EDGE INDEX ON :KNOWS(since, strength)'], adapter.executed
  end

  # --- Vector Index Tests (Memgraph 3.4+) ---

  test 'vector index for Memgraph' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_vector_index :doc_embeddings, :Document, :embedding, dimension: 384
      end
    end

    adapter = CaptureAdapter.new(:memgraph)
    klass.new(adapter).run

    assert_equal 1, adapter.executed.size
    assert_match(/CREATE VECTOR INDEX doc_embeddings ON :Document\(embedding\)/, adapter.executed.first)
    assert_match(/dimension: 384/, adapter.executed.first)
    assert_match(/metric: 'cosine'/, adapter.executed.first)
  end

  test 'vector index with quantization for Memgraph' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_vector_index :embeddings, :Node, :vec, dimension: 128, metric: :euclidean, quantization: :scalar
      end
    end

    adapter = CaptureAdapter.new(:memgraph)
    klass.new(adapter).run

    assert_match(/scalar_kind: 'f32'/, adapter.executed.first)
    assert_match(/metric: 'euclidean'/, adapter.executed.first)
  end

  test 'vector edge index for Memgraph' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_vector_edge_index :rel_embeddings, :SIMILAR_TO, :embedding, dimension: 256
      end
    end

    adapter = CaptureAdapter.new(:memgraph)
    klass.new(adapter).run

    assert_match(/CREATE VECTOR EDGE INDEX rel_embeddings ON :SIMILAR_TO\(embedding\)/, adapter.executed.first)
    assert_match(/dimension: 256/, adapter.executed.first)
  end

  test 'vector edge index for Neo4j 2025' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_vector_edge_index :rel_embeddings, :SIMILAR_TO, :embedding, dimension: 256, metric: :cosine
      end
    end

    adapter = CaptureAdapter.new(:neo4j)
    klass.new(adapter).run

    assert_equal 1, adapter.executed.size
    assert_match(/CREATE VECTOR INDEX rel_embeddings IF NOT EXISTS FOR \(\)-\[r:SIMILAR_TO\]-\(\) ON \(r\.embedding\)/, adapter.executed.first)
    assert_match(/vector\.dimensions.*256/, adapter.executed.first)
    assert_match(/vector\.similarity_function.*cosine/, adapter.executed.first)
  end

  # --- Text Edge Index Tests (Memgraph 3.6+) ---

  test 'text edge index for Memgraph' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_text_edge_index :comment_search, :COMMENTED, :text
      end
    end

    adapter = CaptureAdapter.new(:memgraph)
    klass.new(adapter).run

    assert_equal ['CREATE TEXT EDGE INDEX comment_search ON :COMMENTED(text)'], adapter.executed
  end

  test 'text edge index raises for Neo4j' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_text_edge_index :search, :REL, :content
      end
    end

    adapter = CaptureAdapter.new(:neo4j)
    assert_raises(NotImplementedError) { klass.new(adapter).run }
  end

  # --- Drop All Tests (Memgraph 3.6+) ---

  test 'drop_all_indexes for Memgraph' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        drop_all_indexes
      end
    end

    adapter = CaptureAdapter.new(:memgraph)
    klass.new(adapter).run

    assert_equal ['DROP ALL INDEXES'], adapter.executed
  end

  test 'drop_all_constraints for Memgraph' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        drop_all_constraints
      end
    end

    adapter = CaptureAdapter.new(:memgraph)
    klass.new(adapter).run

    assert_equal ['DROP ALL CONSTRAINTS'], adapter.executed
  end

  test 'drop_all_indexes raises for Neo4j' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        drop_all_indexes
      end
    end

    adapter = CaptureAdapter.new(:neo4j)
    assert_raises(NotImplementedError) { klass.new(adapter).run }
  end

  test 'drop_all_constraints raises for Neo4j' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        drop_all_constraints
      end
    end

    adapter = CaptureAdapter.new(:neo4j)
    assert_raises(NotImplementedError) { klass.new(adapter).run }
  end

  # --- Neo4j Fulltext Relationship Index ---

  test 'fulltext_rel_index for Neo4j' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_fulltext_rel_index :comment_search, :COMMENTED, :text, :summary
      end
    end

    adapter = CaptureAdapter.new(:neo4j)
    klass.new(adapter).run

    assert_equal ['CREATE FULLTEXT INDEX comment_search IF NOT EXISTS FOR ()-[r:COMMENTED]-() ON EACH [r.text, r.summary]'],
                 adapter.executed
  end

  test 'fulltext_rel_index raises for Memgraph' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_fulltext_rel_index :search, :REL, :content
      end
    end

    adapter = CaptureAdapter.new(:memgraph)
    assert_raises(NotImplementedError) { klass.new(adapter).run }
  end

  # --- Vector Index for Neo4j ---

  test 'vector index for Neo4j' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_vector_index :embeddings, :Document, :embedding, dimension: 1536, metric: :cosine
      end
    end

    adapter = CaptureAdapter.new(:neo4j)
    klass.new(adapter).run

    assert_equal 1, adapter.executed.size
    assert_match(/CREATE VECTOR INDEX embeddings IF NOT EXISTS FOR \(n:Document\) ON \(n\.embedding\)/, adapter.executed.first)
    assert_match(/vector\.dimensions.*1536/, adapter.executed.first)
  end
end
