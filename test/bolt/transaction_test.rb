# frozen_string_literal: true

require 'test_helper'
require 'active_cypher/bolt'
require 'async'

class TransactionTest < ActiveSupport::TestCase
  def setup
    # Use the Neo4jRecord connection which is properly configured from cypher_databases.yml
    @connection = Neo4jRecord.connection.raw_connection

    # Clear test data before each test
    Sync do
      session = @connection.session
      session.run('MATCH (n:TestNode) DETACH DELETE n')
    end
  rescue ActiveCypher::ConnectionError => e
    skip "Database connection failed: #{e.message}"
  end

  def teardown
    # Connection is managed by the connection pool, no need to close
  end

  # --- Connection-level synchronous transaction tests ---

  test 'connection read_transaction executes successfully' do
    # Create test data
    Sync do
      session = @connection.session
      session.run('CREATE (n:TestNode {name: "read-test", value: 42})')
    end

    # Use read_transaction
    result = @connection.read_transaction do |tx|
      result = tx.run('MATCH (n:TestNode {name: "read-test"}) RETURN n.value AS value')
      result.single[:value]
    end

    assert_equal 42, result
  end

  test 'connection write_transaction creates data successfully' do
    result = @connection.write_transaction do |tx|
      tx.run('CREATE (n:TestNode {name: "write-test", value: 100}) RETURN n')
      'success'
    end

    assert_equal 'success', result

    # Verify data was created
    Sync do
      session = @connection.session
      result = session.run('MATCH (n:TestNode {name: "write-test"}) RETURN n.value AS value')
      assert_equal 100, result.single[:value]
    end
  end

  test 'connection transaction with database parameter' do
    # Skip if database doesn't support multiple databases
    begin
      @connection.write_transaction(db: 'neo4j') do |tx|
        tx.run('CREATE (n:TestNode {name: "db-test"})')
      end
    rescue ActiveCypher::QueryError => e
      skip "Multiple database support not available: #{e.message}"
    end

    # Verify data was created in specific database
    result = @connection.read_transaction(db: 'neo4j') do |tx|
      result = tx.run('MATCH (n:TestNode {name: "db-test"}) RETURN count(n) AS count')
      result.single[:count]
    end

    assert_equal 1, result
  end

  test 'connection transaction with metadata' do
    metadata = { app_name: 'test_suite', request_id: '12345' }

    result = @connection.write_transaction(metadata: metadata) do |tx|
      tx.run('CREATE (n:TestNode {name: "metadata-test"})')
      'completed'
    end

    assert_equal 'completed', result
  end

  # --- Connection-level asynchronous transaction tests ---

  test 'connection async_read_transaction returns task and executes correctly' do
    # Create test data
    Sync do
      session = @connection.session
      session.run('CREATE (n:TestNode {name: "async-read", value: 99})')
    end

    Async do
      task = @connection.async_read_transaction do |tx|
        result = tx.run('MATCH (n:TestNode {name: "async-read"}) RETURN n.value AS value')
        result.single[:value]
      end

      assert_instance_of Async::Task, task
      value = task.wait
      assert_equal 99, value
    end
  end

  test 'connection async_write_transaction creates data asynchronously' do
    Async do
      task = @connection.async_write_transaction do |tx|
        tx.run('CREATE (n:TestNode {name: "async-write", value: 200})')
        'async-success'
      end

      result = task.wait
      assert_equal 'async-success', result

      # Verify data was created
      verify_task = @connection.async_read_transaction do |tx|
        result = tx.run('MATCH (n:TestNode {name: "async-write"}) RETURN n.value AS value')
        result.single[:value]
      end

      assert_equal 200, verify_task.wait
    end
  end

  test 'multiple async transactions can run concurrently' do
    Async do
      # Create multiple nodes concurrently
      tasks = 5.times.map do |i|
        @connection.async_write_transaction do |tx|
          tx.run('CREATE (n:TestNode {name: $name, value: $value})',
                 { name: "concurrent-#{i}", value: i * 10 })
          i
        end
      end

      # Wait for all tasks to complete
      results = tasks.map(&:wait)
      assert_equal [0, 1, 2, 3, 4], results

      # Verify all nodes were created
      count_task = @connection.async_read_transaction do |tx|
        result = tx.run('MATCH (n:TestNode) WHERE n.name STARTS WITH "concurrent-" RETURN count(n) AS count')
        result.single[:count]
      end

      assert_equal 5, count_task.wait
    end
  end

  # --- Error handling tests ---

  test 'transaction rollback on error' do
    assert_raises(ActiveCypher::TransactionError) do
      @connection.write_transaction do |tx|
        tx.run('CREATE (n:TestNode {name: "rollback-test"})')
        # This should cause an error
        tx.run('INVALID CYPHER QUERY')
      end
    end

    # Verify node was not created due to rollback
    Sync do
      session = @connection.session
      result = session.run('MATCH (n:TestNode {name: "rollback-test"}) RETURN count(n) AS count')
      assert_equal 0, result.single[:count]
    end
  end

  test 'async transaction handles errors correctly' do
    Async do
      task = @connection.async_write_transaction do |tx|
        tx.run('CREATE (n:TestNode {name: "async-error-test"})')
        raise 'Intentional error'
      end

      assert_raises(ActiveCypher::TransactionError) { task.wait }

      # Verify rollback occurred
      verify_task = @connection.async_read_transaction do |tx|
        result = tx.run('MATCH (n:TestNode {name: "async-error-test"}) RETURN count(n) AS count')
        result.single[:count]
      end

      assert_equal 0, verify_task.wait
    end
  end

  test 'transaction preserves original error message' do
    error = assert_raises(ActiveCypher::TransactionError) do
      @connection.write_transaction do |tx|
        raise 'Custom application error'
      end
    end

    assert_match(/Custom application error/, error.message)
  end

  # --- Session-level async transaction tests ---

  test 'session async_run_transaction must be called within Async context' do
    session = @connection.session

    assert_raises(RuntimeError) do
      session.async_run_transaction(:write) do |tx|
        tx.run('CREATE (n:TestNode)')
      end
    end
  end

  test 'session async_write_transaction works correctly' do
    Async do
      session = @connection.session
      task = session.async_write_transaction do |tx|
        tx.run('CREATE (n:TestNode {name: "session-async-write", value: 300})')
        'session-async-success'
      end

      result = task.wait
      assert_equal 'session-async-success', result

      # Verify
      verify_result = session.read_transaction do |tx|
        result = tx.run('MATCH (n:TestNode {name: "session-async-write"}) RETURN n.value AS value')
        result.single[:value]
      end

      assert_equal 300, verify_result
    end
  end

  test 'session async_read_transaction with parameters' do
    # Setup data
    Sync do
      session = @connection.session
      session.run('CREATE (n:TestNode {name: "param-test", value: 500})')
    end

    Async do
      session = @connection.session
      task = session.async_read_transaction(metadata: { test: true }) do |tx|
        result = tx.run('MATCH (n:TestNode {name: $name}) RETURN n.value AS value',
                       { name: 'param-test' })
        result.single[:value]
      end

      assert_equal 500, task.wait
    end
  end

  # --- Timeout tests ---

  test 'transaction with timeout parameter' do
    # This test verifies timeout parameter is accepted
    # Note: Actual timeout behavior depends on database support
    result = @connection.write_transaction(timeout: 5000) do |tx|
      tx.run('CREATE (n:TestNode {name: "timeout-test"})')
      'completed'
    end

    assert_equal 'completed', result

    # Verify the node was created
    Sync do
      session = @connection.session
      result = session.run('MATCH (n:TestNode {name: "timeout-test"}) RETURN count(n) AS count')
      assert_equal 1, result.single[:count]
    end
  end

  test 'async transaction with timeout' do
    Async do
      task = @connection.async_write_transaction(timeout: 1000) do |tx|
        tx.run('CREATE (n:TestNode {name: "async-timeout-test", value: 1000})')
        'timeout-success'
      end

      result = task.wait
      assert_equal 'timeout-success', result
    end
  end
end
