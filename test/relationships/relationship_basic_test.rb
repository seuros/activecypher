# frozen_string_literal: true

require 'test_helper'

class RelationshipBasicTest < ActiveSupport::TestCase
  def setup
    # Clean graph before every test run
    PersonNode.connection.execute_cypher('MATCH (n) DETACH DELETE n')
  end

  test 'create relationship between nodes' do
    # Create nodes
    alice = PersonNode.create(name: 'Alice', age: 30)
    chess = HobbyNode.create(name: 'Chess', category: 'board game', skill_level: 'beginner')

    assert alice.persisted?, 'Person should be persisted'
    assert chess.persisted?, 'Hobby should be persisted'

    # Create relationship
    rel = EnjoysRel.create({ frequency: 'daily', since: Date.today },
                           from_node: alice, to_node: chess)

    # Verify relationship was created
    assert rel.persisted?, 'Relationship should be persisted'
    assert_equal 'ENJOYS', EnjoysRel.relationship_type
    assert_equal alice.internal_id, rel.from_node.internal_id
    assert_equal chess.internal_id, rel.to_node.internal_id

    # Verify in database
    PersonNode.connection.id_handler
    result = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE id(p) = #{alice.internal_id} AND id(h) = #{chess.internal_id}
       RETURN COUNT(r) as count"
    )
    assert_equal 1, result[0][:count], 'Expected one relationship in database'
  end

  test 'relationship with properties' do
    alice = PersonNode.create(name: 'Alice')
    chess = HobbyNode.create(name: 'Chess')

    # Create with properties
    rel = EnjoysRel.create(
      { frequency: 'weekly', since: Date.today - 10 },
      from_node: alice, to_node: chess
    )

    # Verify properties
    assert_equal 'weekly', rel.frequency
    assert_equal Date.today - 10, rel.since.to_date

    # Update properties
    rel.frequency = 'daily'
    rel.save

    # Verify in database
    PersonNode.connection.id_handler
    result = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE id(p) = #{alice.internal_id} AND id(h) = #{chess.internal_id}
       RETURN r.frequency as frequency"
    )
    assert_equal 'daily', result[0][:frequency], 'Property should be updated in database'
  end

  test 'find relationship by id' do
    bob = PersonNode.create(name: 'Bob')
    surf = HobbyNode.create(name: 'Surf')

    # Create relationship
    rel = EnjoysRel.create({ frequency: 'monthly' },
                           from_node: bob, to_node: surf)
    rel.internal_id

    # Verify it exists in database with correct type and endpoints
    PersonNode.connection.id_handler
    count = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE id(p) = #{bob.internal_id} AND id(h) = #{surf.internal_id}
       RETURN COUNT(r) as count"
    )[0][:count]
    assert_equal 1, count, 'Relationship should exist in database'
  end

  test 'delete relationship' do
    alice = PersonNode.create(name: 'Alice')
    chess = HobbyNode.create(name: 'Chess')

    # Create relationship
    rel = EnjoysRel.create({ frequency: 'daily' },
                           from_node: alice, to_node: chess)

    # Verify it exists first
    PersonNode.connection.id_handler
    count_before = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE id(p) = #{alice.internal_id} AND id(h) = #{chess.internal_id}
       RETURN COUNT(r) as count"
    )[0][:count]
    assert_equal 1, count_before, 'Should have one relationship before deletion'

    # Delete it
    rel.destroy

    # Verify it's gone
    count_after = PersonNode.connection.execute_cypher(
      "MATCH (p)-[r:ENJOYS]->(h)
       WHERE id(p) = #{alice.internal_id} AND id(h) = #{chess.internal_id}
       RETURN COUNT(r) as count"
    )[0][:count]
    assert_equal 0, count_after, 'Should have no relationships after deletion'
  end
end
