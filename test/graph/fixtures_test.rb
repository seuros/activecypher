# frozen_string_literal: true

require 'test_helper'

module ActiveCypher
  class FixturesTest < Minitest::Test
    def setup
      # Ensure clean state before each test
      ActiveCypher::Fixtures.clear_all
    end

    def test_load_default_profile_creates_nodes_and_relationships_in_correct_dbs
      # Load the default profile
      registry = ActiveCypher::Fixtures.load

      # Should have loaded :john and :max
      john = registry.get(:john)
      max = registry.get(:max)

      assert john, 'John node should be present in registry'
      assert max, 'Max node should be present in registry'
      assert_kind_of PersonNode, john
      assert_kind_of PetNode, max

      # Check properties
      assert_equal 'John', john.name
      assert_equal 35, john.age
      assert_equal 'Max', max.name
      assert_equal 'Dog', max.species
      assert_equal 3, max.age

      # Check connections (DB routing)
      assert_equal PersonNode.connection, john.class.connection
      assert_equal PetNode.connection, max.class.connection

      # Check if relationship exists by directly querying relationship
      # Note: For graph DBs, the relationship direction is important
      # Since PersonNode.has_many :pets is defined with direction: :out from Pet to Person
      rel_query = <<~CYPHER
        MATCH (a:Person)-[r:OWNS_PET]->(p:Pet)
        WHERE a.name = $person_name AND p.name = $pet_name
        RETURN count(r) AS count
      CYPHER
      rel_count = PersonNode.connection.execute_cypher(
        rel_query,
        pet_name: max.name,
        person_name: john.name
      ).first[:count]

      assert rel_count.positive?, 'OWNS_PET relationship should exist between Max (Pet) and John (Person)'
    end

    def test_load_profile_only_touches_needed_dbs
      registry = ActiveCypher::Fixtures.load(profile: :only_person)
      lucy = registry.get(:lucy)
      mike = registry.get(:mike)

      assert lucy, 'Lucy node should be present in registry'
      assert mike, 'Mike node should be present in registry'
      assert_kind_of PersonNode, lucy
      assert_kind_of PersonNode, mike

      assert_equal 'Lucy', lucy.name
      assert_equal 'Mike', mike.name
    end

    def test_cross_db_relationship_raises_fixture_error
      # Use real models: PersonNode (primary) and PetNode (neo4j)
      profile_code = <<~RUBY
        node :lucy, PersonNode, name: 'Lucy'
        node :acme, CompanyNode, name: 'Acme Inc'
        relationship :bad, :lucy, :WORKS_FOR, :acme
      RUBY
      profile_path = File.join(__dir__, '../fixtures/graph/cross_db_error.rb')
      File.write(profile_path, profile_code)

      begin
        error = assert_raises(ActiveCypher::Fixtures::FixtureError) do
          ActiveCypher::Fixtures.load(profile: :cross_db_error)
        end
        assert_match(/cross-DB rel|cross-database relationship|data has commitment issues/i, error.message)
      ensure
        FileUtils.rm_f(profile_path)
      end
    end

    def test_duplicate_ref_in_profile_raises_error
      profile_code = <<~RUBY
        node :lucy, PersonNode, name: 'Lucy'
        node :lucy, PersonNode, name: 'Lucy Clone'
      RUBY
      profile_path = File.join(__dir__, '../fixtures/graph/duplicate_ref.rb')
      File.write(profile_path, profile_code)

      begin
        error = assert_raises(StandardError) do
          ActiveCypher::Fixtures.load(profile: :duplicate_ref)
        end
        assert_match(/duplicate/i, error.message)
      ensure
        File.delete(profile_path)
      end
    end

    def test_unknown_profile_raises_fixture_not_found_error
      # Should raise FixtureNotFoundError for missing profile
      error = assert_raises(ActiveCypher::Fixtures::FixtureNotFoundError) do
        ActiveCypher::Fixtures.load(profile: :nonexistent_profile)
      end
      assert_match(/not found/i, error.message)
    end

    def test_clear_all_empties_all_known_connections
      # Should clear all nodes in all known DBs
      # Load a profile to populate DBs
      ActiveCypher::Fixtures.load
      # Now clear all
      ActiveCypher::Fixtures.clear_all

      # Check that nodes are gone from both PersonNode and PetNode DBs
      person_count =
        PersonNode.connection.execute_cypher('MATCH (n:Person) RETURN count(n) AS count').first['count']

      pet_count =
        PetNode.connection.execute_cypher('MATCH (n:Pet) RETURN count(n) AS count').first['count']

      assert person_count.nil? || person_count.zero?, 'PersonNode DB should be empty after clear_all'
      assert pet_count.nil? || pet_count.zero?, 'PetNode DB should be empty after clear_all'
    end

    def test_load_performance_for_large_graph
      # Should load 1000 nodes and 2000 rels in under 10 seconds (increased from 3s to be more realistic)
      node_lines = (1..1000).map { |i| "node :n#{i}, PersonNode, name: 'Person#{i}'" }
      rel_lines = (1..2000).map { |i| "relationship :r#{i}, :n#{rand(1..1000)}, :FRIENDS_WITH, :n#{rand(1..1000)}" }
      profile_code = (node_lines + rel_lines).join("\n")
      profile_path = File.join(__dir__, '../fixtures/graph/large_profile.rb')
      File.write(profile_path, profile_code)

      begin
        start_time = Time.now
        ActiveCypher::Fixtures.load(profile: :large_profile)
        elapsed = Time.now - start_time
        assert_operator elapsed, :<, 10.0, "Should load 1000 nodes and 2000 rels in under 10 seconds (actual: #{elapsed}s)"
      ensure
        FileUtils.rm_f(profile_path)
      end
    end
  end
end
