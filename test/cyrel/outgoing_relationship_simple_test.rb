# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

module Cyrel
  class OutgoingRelationshipSimpleTest < ActiveSupport::TestCase
    test 'outgoing relationship simple match' do
      # Define the pattern
      user_node = Cyrel::Pattern::Node.new(:user, labels: 'User', properties: { name: 'John' })
      rel = Cyrel::Pattern::Relationship.new(types: 'FRIENDS_WITH', direction: :outgoing)
      person_node = Cyrel::Pattern::Node.new(:person, labels: 'Person')
      path = Cyrel::Pattern::Path.new([user_node, rel, person_node])

      # Build the query
      query = Cyrel::Query.new
                          .match(path)
                          .return_(Cyrel.prop(:person, :name))

      expected_cypher = <<~CYPHER.chomp.strip
        MATCH (user:User {name: $p1})-[:FRIENDS_WITH]->(person:Person)
        RETURN person.name
      CYPHER
      expected_params = { p1: 'John' }

      assert_equal [expected_cypher, expected_params], query.to_cypher
    end
  end
end
