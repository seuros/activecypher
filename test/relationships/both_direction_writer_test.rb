# frozen_string_literal: true

require 'test_helper'

class BothDirectionWriterTest < ActiveSupport::TestCase
  setup do
    # Clear the database before each test
    PersonNode.connection.execute_cypher('MATCH (n) DETACH DELETE n')

    # Create test nodes
    @bob = PersonNode.create(name: 'Bob')
    @chess = HobbyNode.create(name: 'Chess')

    # Ensure nodes are persisted
    assert @bob.persisted?, 'PersonNode should be persisted'
    assert @chess.persisted?, 'HobbyNode should be persisted'
  end

  test 'directional relationship can be created' do
    # Create a relationship directly
    rel = EnjoysRelationship.create({}, from_node: @bob, to_node: @chess)
    assert rel.persisted?, 'Relationship should be persisted'

    # Verify relationship exists in database with the correct direction
    # Should find when searching for p->h
    adapter = PersonNode.connection.id_handler
    count_out = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE #{adapter.with_direct_node_ids(@bob.internal_id, @chess.internal_id)}
       RETURN COUNT(r) as count"
    )[0][:count]
    assert_equal 1, count_out, 'Expected one outgoing relationship'

    # Should find when searching for undirected p-h (either direction)
    count_either = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]-(h)
       WHERE #{adapter.with_direct_node_ids(@bob.internal_id, @chess.internal_id)}
       RETURN COUNT(r) as count"
    )[0][:count]
    assert_equal 1, count_either, 'Expected one relationship in either direction'
  end

  test 'multiple relationships can exist between the same nodes' do
    # Create first relationship
    rel1 = EnjoysRelationship.create({ frequency: 'daily' }, from_node: @bob, to_node: @chess)

    # Create second relationship
    rel2 = EnjoysRelationship.create({ frequency: 'weekly' }, from_node: @bob, to_node: @chess)

    # Verify both are persisted
    assert rel1.persisted?
    assert rel2.persisted?

    # Verify there are two relationships between the nodes
    adapter = PersonNode.connection.id_handler
    count = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE #{adapter.with_direct_node_ids(@bob.internal_id, @chess.internal_id)}
       RETURN COUNT(r) as count"
    )[0][:count]
    assert_equal 2, count, 'Expected two relationships between nodes'

    # Verify the properties are correct
    frequencies = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE #{adapter.with_direct_node_ids(@bob.internal_id, @chess.internal_id)}
       RETURN r.frequency as frequency"
    ).map { |row| row[:frequency] }

    assert_includes frequencies, 'daily', "Should have a relationship with frequency 'daily'"
    assert_includes frequencies, 'weekly', "Should have a relationship with frequency 'weekly'"
  end

  test 'relationships can be deleted' do
    # Create relationship
    rel = EnjoysRelationship.create({}, from_node: @bob, to_node: @chess)
    assert rel.persisted?

    # Verify it exists
    adapter = PersonNode.connection.id_handler
    count_before = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE #{adapter.with_direct_node_ids(@bob.internal_id, @chess.internal_id)}
       RETURN COUNT(r) as count"
    )[0][:count]
    assert_equal 1, count_before, 'Should have one relationship before deletion'

    # Delete it
    rel.destroy

    # Verify it's gone
    count_after = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE #{adapter.with_direct_node_ids(@bob.internal_id, @chess.internal_id)}
       RETURN COUNT(r) as count"
    )[0][:count]
    assert_equal 0, count_after, 'Should have no relationships after deletion'
  end
end
