# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

module Cyrel
  class ActiveCypherRelationshipDirectionalityTest < ActiveSupport::TestCase
    test 'relationship incoming query direction' do
      alice = PersonNode.create(name: 'Alice')
      chess = HobbyNode.create(name: 'Chess')
      rel = EnjoysRel.create(
        { frequency: 'weekly', since: Date.today - 10 },
        from_node: alice, to_node: chess
      )
      reflection = chess.people.reflection
      expected_reflection = { class_name: 'PersonNode', relationship: 'ENJOYS', direction: :in, relationship_class: 'EnjoysRel', macro: :has_many, name: :people }
      assert_equal expected_reflection, reflection

      cypher_string, params_hash = chess.people.cyrel_query.to_cypher
      expected_cypher = <<~CYPHER.chomp.strip
        MATCH (start:Activity)<-[:ENJOYS]-(target:Person)
        WHERE (__NODE_ID__(start) = $p1)
        RETURN target
      CYPHER
      expected_params = { p1: chess.internal_id }
      assert_equal [expected_cypher, expected_params], [cypher_string, params_hash]
    end

    test 'relationship outgoing query direction' do
      alice = PersonNode.create(name: 'Alice')
      chess = HobbyNode.create(name: 'Chess')
      rel = EnjoysRel.create(
        { frequency: 'weekly', since: Date.today - 10 },
        from_node: alice, to_node: chess
      )

      cypher_string, params_hash = alice.hobbies.cyrel_query.to_cypher
      expected_cypher = <<~CYPHER.chomp.strip
        MATCH (start:Person)-[:ENJOYS]->(target:Activity)
        WHERE (__NODE_ID__(start) = $p1)
        RETURN target
      CYPHER
      expected_params = { p1: alice.internal_id }
      assert_equal [expected_cypher, expected_params], [cypher_string, params_hash]
    end
  end
end
