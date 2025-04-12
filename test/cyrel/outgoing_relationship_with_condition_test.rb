# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

module Cyrel
  class OutgoingRelationshipWithConditionTest < ActiveSupport::TestCase
    test 'outgoing relationship with condition on related node' do
      # Define the pattern including properties on both nodes
      user_node = Cyrel::Pattern::Node.new(:user, labels: 'User', properties: { name: 'John' })
      rel = Cyrel::Pattern::Relationship.new(types: 'FRIENDS_WITH', direction: :outgoing)
      person_node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { age: 30 })
      path = Cyrel::Pattern::Path.new([user_node, rel, person_node])

      # Build the query
      query = Cyrel::Query.new
                          .match(path)
                          .return_(Cyrel.prop(:person, :name))

      expected_cypher = <<~CYPHER.chomp.strip
        MATCH (user:User {name: $p1})-[:FRIENDS_WITH]->(person:Person {age: $p2})
        RETURN person.name
      CYPHER
      expected_params = { p1: 'John', p2: 30 }

      assert_equal [expected_cypher, expected_params], query.to_cypher
    end
  end
end
