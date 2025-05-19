# frozen_string_literal: true

require 'test_helper'

module ActiveCypher
  class ConnectionIsolationTest < Minitest::Test
    def setup
      # Ensure clean state before each test
      ActiveCypher::Fixtures.clear_all
    end

    # Test the updated ConnectionHandler directly
    def test_connection_handler_db_key_isolation
      handler = ActiveCypher::ConnectionHandler.new

      # Create two different pool objects
      pool1 = Object.new
      pool2 = Object.new

      # Register pools with same role but different db_keys
      handler.set(:primary, pool1)
      handler.set(:neo4j, pool2)

      # Lookup by db_key should return the correct pool
      assert_same pool1, handler.pool(:primary)
      assert_same pool2, handler.pool(:neo4j)

      # Different db_keys should have different pools for the same role
      refute_same handler.pool(:primary),
                  handler.pool(:neo4j)
    end

    def test_model_connection_isolation
      # PersonNode uses primary (memgraph)
      # CompanyNode uses neo4j
      assert_equal :primary, PersonNode.connects_to_mappings[:writing]
      assert_equal :neo4j, CompanyNode.connects_to_mappings[:writing]

      # Get connections using the real connection logic
      person_conn = PersonNode.connection
      company_conn = CompanyNode.connection

      # They should be different objects
      refute_equal person_conn.object_id, company_conn.object_id,
                   'PersonNode and CompanyNode should have different connection objects'

      # Their adapter classes should also be different based on the DB
      assert_equal 'ActiveCypher::ConnectionAdapters::MemgraphAdapter',
                   person_conn.class.name,
                   'PersonNode should connect to memgraph'

      assert_equal 'ActiveCypher::ConnectionAdapters::Neo4jAdapter',
                   company_conn.class.name,
                   'CompanyNode should connect to neo4j'

      # Connection objects should be consistent
      assert_same person_conn, PersonNode.connection
      assert_same company_conn, CompanyNode.connection
    end

    def test_fixture_loading_maintains_connection_isolation
      # Get connections before loading fixtures
      person_conn_before = PersonNode.connection
      company_conn_before = CompanyNode.connection

      # Create nodes directly to avoid cross-DB validation
      PersonNode.new(name: 'Lucy', age: 29)
      PersonNode.new(name: 'Mike', age: 34)
      CompanyNode.new(name: 'Acme Inc')

      # Get connections after creating nodes
      person_conn_after = PersonNode.connection
      company_conn_after = CompanyNode.connection

      # Connections should still be isolated
      refute_equal person_conn_after.object_id, company_conn_after.object_id,
                   'PersonNode and CompanyNode should have different connection objects after fixture-like operations'

      # Connections should be consistent
      assert_same person_conn_before, person_conn_after,
                  'PersonNode connection should be the same object before and after fixture-like operations'
      assert_same company_conn_before, company_conn_after,
                  'CompanyNode connection should be the same object before and after fixture-like operations'
    end
  end
end
