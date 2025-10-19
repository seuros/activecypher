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

    def test_connection_switches_with_role
      old_mapping = PersonNode.connects_to_mappings.dup
      old_runtime_role = ActiveCypher::RuntimeRegistry.current_role

      PersonNode.connects_to writing: :primary, reading: :neo4j

      ActiveCypher::RuntimeRegistry.current_role = :writing
      writing_conn = PersonNode.connection

      ActiveCypher::RuntimeRegistry.current_role = :reading
      reading_conn = PersonNode.connection

      refute_same writing_conn, reading_conn,
                  'Reading role should return a different connection object when mapped to a different database'
      assert_equal 'ActiveCypher::ConnectionAdapters::MemgraphAdapter',
                   writing_conn.class.name
      assert_equal 'ActiveCypher::ConnectionAdapters::Neo4jAdapter',
                   reading_conn.class.name

      ActiveCypher::RuntimeRegistry.current_role = :writing

      PersonNode.connected_to(role: :reading) do
        assert_same reading_conn, PersonNode.connection,
                    'connected_to should use the reading connection inside the block'
        assert_equal :reading, ActiveCypher::RuntimeRegistry.current_role
      end

      assert_same writing_conn, PersonNode.connection,
                  'connected_to should restore the previous role after the block'
      assert_equal :writing, ActiveCypher::RuntimeRegistry.current_role
    ensure
      PersonNode.connects_to old_mapping if old_mapping
      ActiveCypher::RuntimeRegistry.current_role = old_runtime_role || :writing
    end

    def test_missing_role_falls_back_to_writing_connection
      old_mapping = PersonNode.connects_to_mappings.dup
      PersonNode.connects_to writing: :primary, reading: :neo4j

      ActiveCypher::RuntimeRegistry.current_role = :analytics # role not configured
      connection = PersonNode.connection

      assert_equal 'ActiveCypher::ConnectionAdapters::MemgraphAdapter',
                   connection.class.name,
                   'Missing role should fall back to the writing connection'
    ensure
      PersonNode.connects_to old_mapping if old_mapping
      ActiveCypher::RuntimeRegistry.current_role = :writing
    end

    def test_roles_sharing_same_spec_use_single_pool
      old_mapping = PersonNode.connects_to_mappings.dup
      PersonNode.connects_to writing: :primary, reading: :primary

      ActiveCypher::RuntimeRegistry.current_role = :writing
      writing_conn = PersonNode.connection

      PersonNode.connected_to(role: :reading) do
        assert_same writing_conn, PersonNode.connection,
                    'Reading role should reuse the writing connection when mapped to the same key'
        assert_equal :reading, ActiveCypher::RuntimeRegistry.current_role
      end

      assert_same writing_conn, PersonNode.connection,
                  'After leaving connected_to block, connection should be restored to writing instance'
    ensure
      PersonNode.connects_to old_mapping if old_mapping
      ActiveCypher::RuntimeRegistry.current_role = :writing
    end

    def test_connected_to_updates_shard_context
      previous_shard = ActiveCypher::RuntimeRegistry.current_shard

      PersonNode.connected_to(role: :writing, shard: :eu_central) do
        assert_equal :eu_central, ActiveCypher::RuntimeRegistry.current_shard,
                     'connected_to should assign the shard for the duration of the block'
      end

      assert_equal previous_shard, ActiveCypher::RuntimeRegistry.current_shard,
                   'connected_to should restore the previous shard after the block'
    end

    def test_relationships_delegate_connection_with_role_switch
      old_mapping = PersonNode.connects_to_mappings.dup
      PersonNode.connects_to writing: :primary, reading: :neo4j

      ActiveCypher::RuntimeRegistry.current_role = :writing
      person_conn = PersonNode.connection
      rel_conn_writing = OwnsPetRel.connection

      assert_same person_conn, rel_conn_writing,
                  'Relationship connection should delegate to originating node connection for writing role'

      ActiveCypher::RuntimeRegistry.current_role = :reading
      person_read_conn = PersonNode.connection
      rel_conn_reading = OwnsPetRel.connection

      assert_same person_read_conn, rel_conn_reading,
                  'Relationship connection should delegate to originating node connection for reading role'
    ensure
      PersonNode.connects_to old_mapping if old_mapping
      ActiveCypher::RuntimeRegistry.current_role = :writing
    end

    def test_nested_connected_to_blocks_restore_context
      original_role = ActiveCypher::RuntimeRegistry.current_role
      original_shard = ActiveCypher::RuntimeRegistry.current_shard

      PersonNode.connected_to(role: :reading, shard: :eu) do
        assert_equal :reading, ActiveCypher::RuntimeRegistry.current_role
        assert_equal :eu, ActiveCypher::RuntimeRegistry.current_shard

        PersonNode.connected_to(role: :writing, shard: :us) do
          assert_equal :writing, ActiveCypher::RuntimeRegistry.current_role
          assert_equal :us, ActiveCypher::RuntimeRegistry.current_shard
        end

        assert_equal :reading, ActiveCypher::RuntimeRegistry.current_role,
                     'Inner block should restore outer role'
        assert_equal :eu, ActiveCypher::RuntimeRegistry.current_shard,
                     'Inner block should restore outer shard'
      end

      assert_equal original_role, ActiveCypher::RuntimeRegistry.current_role
      assert_equal original_shard, ActiveCypher::RuntimeRegistry.current_shard
    end

    def test_hash_based_role_and_shard_mapping
      old_mapping = PersonNode.connects_to_mappings.dup
      PersonNode.connects_to writing: :primary,
                             reading: { analytics: :neo4j, default: :primary }

      ActiveCypher::RuntimeRegistry.current_role = :reading

      ActiveCypher::RuntimeRegistry.current_shard = :analytics
      analytics_conn = PersonNode.connection
      assert_equal 'ActiveCypher::ConnectionAdapters::Neo4jAdapter',
                   analytics_conn.class.name,
                   'Analytics shard should route to Neo4j adapter'

      ActiveCypher::RuntimeRegistry.current_shard = :default
      default_conn = PersonNode.connection
      assert_equal 'ActiveCypher::ConnectionAdapters::MemgraphAdapter',
                   default_conn.class.name,
                   'Default shard should fall back to primary Memgraph adapter'
    ensure
      PersonNode.connects_to old_mapping if old_mapping
      ActiveCypher::RuntimeRegistry.current_role = :writing
      ActiveCypher::RuntimeRegistry.current_shard = :default
    end
  end
end
