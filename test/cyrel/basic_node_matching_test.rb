# frozen_string_literal: true

require 'test_helper'
require 'cyrel' # Ensure Cyrel and its components are loaded

class BasicNodeMatchingTest < ActiveSupport::TestCase
  test 'basic node matching' do
    person_node = Cyrel::Pattern::Node.new(:person, labels: ['Person'], properties: { name: 'Alice' })
    query = Cyrel::Query.new
                        .match(person_node)
                        .return_('person.name') # Use string for explicit return

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person {name: $p1})
      RETURN person.name
    CYPHER
    expected_params = { p1: 'Alice' }

    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'multiple conditions in node properties' do
    person_node = Cyrel::Pattern::Node.new(:person, labels: ['Person'], properties: { name: 'Alice', age: 30 })
    query = Cyrel::Query.new
                        .match(person_node)
                        .return_('person.name')

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person {name: $p1, age: $p2})
      RETURN person.name
    CYPHER
    expected_params = { p1: 'Alice', p2: 30 }

    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'outgoing relationship simple' do
    user_node = Cyrel::Pattern::Node.new(:user, labels: ['User'], properties: { name: 'John' })
    rel = Cyrel::Pattern::Relationship.new(types: ['FRIENDS_WITH'], direction: :outgoing)
    person_node = Cyrel::Pattern::Node.new(:person, labels: ['Person'])
    path = Cyrel::Pattern::Path.new([user_node, rel, person_node])

    query = Cyrel::Query.new
                        .match(path)
                        .return_('person.name')

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (user:User {name: $p1})-[:FRIENDS_WITH]->(person:Person)
      RETURN person.name
    CYPHER
    expected_params = { p1: 'John' }

    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  # Removed tests for ambiguous names as the new structure requires explicit returns
  # test "ambiguous name should raise error" do ... end
  # test "ambiguous name should raise error with outgoing relationship" do ... end
end
