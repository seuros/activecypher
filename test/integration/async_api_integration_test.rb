# frozen_string_literal: true

require 'test_helper'
require 'async'

class AsyncApiIntegrationTest < ActiveSupport::TestCase
  def setup
    # Clear the database before each test
    adapter.with_session do |session|
      session.run('MATCH (n) DETACH DELETE n')
    end
  end

  def test_async_with_session_returns_correct_data
    # Create some test data synchronously first
    adapter.with_session do |session|
      session.run("CREATE (:Person {name: 'Alice'})")
    end

    Async do
      # Use async_with_session to fetch the data
      task = adapter.async_with_session do |session|
        result = session.run("MATCH (p:Person {name: 'Alice'}) RETURN p.name AS name", {}, mode: :read)
        result.single[:name]
      end

      result = task.wait

      assert_equal 'Alice', result
    end
  end

  def test_async_with_session_creates_data
    Async do
      # Use async_with_session to create a new node
      write_task = adapter.async_with_session do |session|
        session.run("CREATE (:Person {name: 'Bob'})")
      end
      write_task.wait

      # Use async_with_session to verify the node was created
      read_task = adapter.async_with_session do |session|
        result = session.run("MATCH (p:Person {name: 'Bob'}) RETURN p.name AS name", {}, mode: :read)
        result.single[:name]
      end

      result = read_task.wait
      assert_equal 'Bob', result
    end
  end

  private

  def adapter
    # Use Neo4jRecord adapter since Memgraph doesn't support transactions
    Neo4jRecord.connection
  end
end
