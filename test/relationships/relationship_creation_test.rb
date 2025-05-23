# frozen_string_literal: true

require 'test_helper'

class RelationshipCreationTest < ActiveSupport::TestCase
  setup do
    # Clear database before each test
    PersonNode.connection.execute_cypher('MATCH (n) DETACH DELETE n')

    # Create test nodes
    @alice = PersonNode.create(name: 'Alice')
    @chess = HobbyNode.create(name: 'Chess')

    # Ensure nodes are persisted
    assert @alice.persisted?, 'PersonNode should be persisted'
    assert @chess.persisted?, 'HobbyNode should be persisted'
  end

  test 'creates relationship without properties' do
    # Create relationship without properties
    rel = EnjoysRel.create({}, from_node: @alice, to_node: @chess)

    # Verify relationship was created
    assert rel.persisted?, 'Relationship should be persisted'
    refute_nil rel.internal_id, 'Relationship should have an internal ID'

    # Get adapter for proper ID handling
    adapter = PersonNode.connection.id_handler

    # Verify relationship exists in database
    result = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE #{adapter.with_direct_node_ids(@alice.internal_id, @chess.internal_id)}
       RETURN COUNT(r) as count"
    )
    assert_equal 1, result[0][:count], 'Expected one ENJOYS relationship in database'
  end

  test 'creates relationship and sets properties' do
    # Create relationship with properties
    rel = EnjoysRel.create({ frequency: 'daily', since: Date.today }, from_node: @alice, to_node: @chess)

    # Verify relationship was created
    assert rel.persisted?, 'Relationship should be persisted'
    refute_nil rel.internal_id, 'Relationship should have an internal ID'

    # Verify properties were set
    assert_equal 'daily', rel.frequency, 'Relationship property should be set'

    # Verify relationship exists in database with correct property
    adapter = PersonNode.connection.id_handler
    result = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE #{adapter.with_direct_node_ids(@alice.internal_id, @chess.internal_id)}
       RETURN r.frequency as frequency"
    )
    assert_equal 'daily', result[0][:frequency], "Expected frequency property to be 'daily'"
  end

  test 'updates relationship properties' do
    # Create relationship with properties
    rel = EnjoysRel.create({ frequency: 'weekly' }, from_node: @alice, to_node: @chess)

    # Update properties
    rel.frequency = 'daily'
    rel.save

    # Verify properties were updated in database
    adapter = PersonNode.connection.id_handler
    result = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE #{adapter.with_direct_node_ids(@alice.internal_id, @chess.internal_id)}
       RETURN r.frequency as frequency"
    )
    assert_equal 'daily', result[0][:frequency], 'Expected frequency property to be updated'
  end

  test 'destroys relationship' do
    # Create relationship

    rel = EnjoysRel.create({ frequency: 'monthly' }, from_node: @alice, to_node: @chess)
    assert rel.persisted?

    # Count relationships before deletion
    adapter = PersonNode.connection.id_handler
    result_before = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE #{adapter.with_direct_node_ids(@alice.internal_id, @chess.internal_id)}
       RETURN COUNT(r) as count"
    )
    assert_equal 1, result_before[0][:count], 'Expected one relationship before deletion'

    # Destroy relationship
    rel.destroy

    # Count relationships after deletion
    result_after = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE #{adapter.with_direct_node_ids(@alice.internal_id, @chess.internal_id)}
       RETURN COUNT(r) as count"
    )
    assert_equal 0, result_after[0][:count], 'Expected no relationships after deletion'
  end

  test 'can create multiple relationships between same nodes' do
    # Create first relationship
    rel1 = EnjoysRel.create({ frequency: 'daily' }, from_node: @alice, to_node: @chess)

    # Create second relationship
    rel2 = EnjoysRel.create({ frequency: 'weekly' }, from_node: @alice, to_node: @chess)

    # Both should be persisted with different IDs
    assert rel1.persisted?
    assert rel2.persisted?
    refute_equal rel1.internal_id, rel2.internal_id

    # Count relationships in database
    adapter = PersonNode.connection.id_handler
    result = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE #{adapter.with_direct_node_ids(@alice.internal_id, @chess.internal_id)}
       RETURN COUNT(r) as count"
    )
    assert_equal 2, result[0][:count], 'Expected two relationships in database'
  end
end
