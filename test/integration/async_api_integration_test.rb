# frozen_string_literal: true

require 'test_helper'
require 'async'

class AsyncApiIntegrationTest < ActiveSupport::TestCase
  def setup
    # Clear the database before each test
    connection.raw_connection.write_transaction do |tx|
      tx.run('MATCH (n) DETACH DELETE n')
    end
  end

  def test_async_read_transaction_returns_correct_data
    # Create some test data synchronously first
    connection.raw_connection.write_transaction do |tx|
      tx.run("CREATE (:Person {name: 'Alice'})")
    end

    Async do
      # Use async_read_transaction to fetch the data
      task = connection.raw_connection.async_read_transaction do |tx|
        result = tx.run("MATCH (p:Person {name: 'Alice'}) RETURN p.name AS name")
        result.single[:name]
      end

      result = task.wait

      assert_equal 'Alice', result
    end
  end

  def test_async_write_transaction_creates_data
    Async do
      # Use async_write_transaction to create a new node
      write_task = connection.raw_connection.async_write_transaction do |tx|
        tx.run("CREATE (:Person {name: 'Bob'})")
      end
      write_task.wait

      # Use async_read_transaction to verify the node was created
      read_task = connection.raw_connection.async_read_transaction do |tx|
        result = tx.run("MATCH (p:Person {name: 'Bob'}) RETURN p.name AS name")
        result.single[:name]
      end

      result = read_task.wait
      assert_equal 'Bob', result
    end
  end

  private

  def connection
    # Use Neo4jRecord connection since Memgraph doesn't support transactions
    Neo4jRecord.connection
  end
end
