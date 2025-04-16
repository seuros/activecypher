# frozen_string_literal: true

require 'test_helper'

class MemgraphAdapterIntegrationTest < ActiveSupport::TestCase
  def setup
    # Clean the database before each test
    clear_database

    # Create initial data for fetching tests
    begin
      connection.execute_cypher(
        "CREATE (:Person {name: 'Bob', age: 40, active: true}), (:Person {name: 'Charlie', age: 50, active: false})",
        {} # Pass empty params explicitly
      )
    rescue ActiveCypher::Error => e
      puts "[DEBUG Test] ERROR creating initial data in Memgraph: #{e.class} - #{e.message}"
      raise # Fail setup if data creation fails
    end
  end

  def teardown
    ActiveCypher::Base.connection&.disconnect
  end

  # --- Test Cases (Copied and adapted from Neo4j tests) ---

  def test_find_fetches_correct_node
    # Create a unique person for this test
    person_to_find = PersonNode.create(name: 'FindMe', age: 99, active: false)
    assert person_to_find.persisted?, 'Person should be persisted after create'
    refute_nil person_to_find.internal_id, 'Persisted person should have an internal_id'

    # Fetch the person using the internal ID
    found_person = PersonNode.find(person_to_find.internal_id)

    assert_instance_of PersonNode, found_person, 'Should return a Person instance'
    assert found_person.persisted?, 'Found person should be persisted'
    assert_equal person_to_find.internal_id, found_person.internal_id,
                 'Found person should have the correct internal_id'
    assert_equal 'FindMe', found_person.name
    assert_equal 99, found_person.age
    assert_equal false, found_person.active
  end

  def test_where_fetches_multiple_nodes
    # Fetch all people (Bob and Charlie created in setup)
    results = PersonNode.all.to_a # Use .to_a to execute

    # Should find Bob and Charlie
    assert_equal 2, results.length, "Should find two people, found #{results.length}"
    names = results.map(&:name).sort
    assert_equal %w[Bob Charlie], names
  end

  def test_where_with_boolean
    # Fetch active people (only Bob)
    results = PersonNode.where(active: true).to_a

    assert_equal 1, results.length, 'Should find only one active person'
    assert_equal 'Bob', results.first.name
  end

  # --- Helper Methods ---
  private

  def connection
    ApplicationGraphNode.connection
  end

  # Helper to clear the Memgraph database between tests
  def clear_database
    connection.send :wipe_database, confirm: 'yes, really'
  end
end
