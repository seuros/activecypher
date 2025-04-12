# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class OptionalMatchTest < ActiveSupport::TestCase
  test 'optional match' do
    # Define the pattern for the initial match
    person_node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice' })

    # Define the pattern for the optional match
    knows_rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', direction: :outgoing)
    friend_node = Cyrel::Pattern::Node.new(:friend, labels: 'Person') # Use distinct alias 'friend'
    optional_path = Cyrel::Pattern::Path.new([person_node, knows_rel, friend_node]) # Path starts from the already defined 'person'

    # Build the query
    query = Cyrel::Query.new
                        .match(person_node) # Match the initial person
                        .optional_match(optional_path) # Optionally match the relationship and friend
                        .return_(Cyrel.prop(:friend, :name)) # Return the friend's name

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person {name: $p1})
      OPTIONAL MATCH (person:Person {name: $p1})-[:KNOWS]->(friend:Person)
      RETURN friend.name
    CYPHER
    # NOTE: Parameter reuse means only one parameter is expected.
    expected_params = { p1: 'Alice' } # Updated for parameter reuse

    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
