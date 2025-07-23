# frozen_string_literal: true

require 'test_helper'
require 'active_cypher/bolt'
require 'async'

class SessionTest < ActiveSupport::TestCase

  # --- Neo4j Tests ---

  test '[Neo4j] session can run simple query and get result' do
    connection = neo4j_connection
    session = ActiveCypher::Bolt::Session.new(connection)

    result = Sync do
      session.run('RETURN 1 AS n')
    end

    assert_instance_of ActiveCypher::Bolt::Result, result
    assert_equal [:n], result.fields.map(&:to_sym)

    record = result.single # Consumes the result
    assert_equal({ n: 1 }, record)

    assert_equal false, result.open? # Should be consumed
    assert_kind_of Hash, result.summary # Check summary is accessible
  ensure
  end

  test '[Neo4j] session can run query with parameters' do
    connection = neo4j_connection
    session = ActiveCypher::Bolt::Session.new(connection)

    result = Sync do
      session.run('RETURN $x + $y AS total', { x: 10, y: 5 })
    end

    record = result.single
    assert_equal({ total: 15 }, record)
  ensure
  end

  test '[Neo4j] session handles database error' do
    connection = neo4j_connection
    session = ActiveCypher::Bolt::Session.new(connection)

    Sync do
      error = assert_raises(ActiveCypher::QueryError) do
        session.run('RETURN invalid_function()')
      end

      assert_match(/Unknown function/, error.message)
    end
  ensure
  end

  test '[Neo4j] session can handle multiple results' do
    connection = neo4j_connection
    session = ActiveCypher::Bolt::Session.new(connection)

    result = Sync do
      session.run('UNWIND [1, 2, 3, 4, 5] AS n RETURN n')
    end

    # Should have 5 records
    records = result.to_a
    assert_equal 5, records.size

    # Values should be 1 through 5
    values = records.map { |r| r[:n] }
    assert_equal [1, 2, 3, 4, 5], values
  ensure
  end

  test '[Neo4j] session supports iteration' do
    connection = neo4j_connection
    session = ActiveCypher::Bolt::Session.new(connection)

    result = Sync do
      session.run('UNWIND [1, 2, 3] AS n RETURN n')
    end

    # Test iteration with each
    sum = 0
    result.each do |record|
      sum += record[:n]
    end

    assert_equal 6, sum
    assert_equal false, result.open? # Should be consumed after iteration
  ensure
  end

  # Additional tests that could be implemented:

  # test '[Neo4j] session supports write transactions' do
  #  connection = setup_connection(NEO4J_CONFIG)
  #  session = ActiveCypher::Bolt::Session.new(connection)
  #
  #  Sync do
  #    session.write_transaction do |tx|
  #      tx.run('CREATE (n:TestNode {name: $name})', { name: 'test-node' })
  #    end
  #
  #    result = session.run('MATCH (n:TestNode {name: "test-node"}) RETURN count(n) AS count')
  #    assert_equal 1, result.single[:count]
  #
  #    # Clean up
  #    session.run('MATCH (n:TestNode) DELETE n')
  #  end
  # ensure
  #  teardown_connection(connection)
  # end

  # test '[Neo4j] session supports read transactions' do
  #  connection = setup_connection(NEO4J_CONFIG)
  #  session = ActiveCypher::Bolt::Session.new(connection)
  #
  #  Sync do
  #    # Setup test data
  #    session.run('CREATE (n:TestNode {name: "read-test"}) RETURN n')
  #
  #    # Test read transaction
  #    session.read_transaction do |tx|
  #      result = tx.run('MATCH (n:TestNode {name: "read-test"}) RETURN n.name')
  #      assert_equal 'read-test', result.single[:name]
  #    end
  #
  #    # Clean up
  #    session.run('MATCH (n:TestNode) DELETE n')
  #  end
  # ensure
  #  teardown_connection(connection)
  # end
end
