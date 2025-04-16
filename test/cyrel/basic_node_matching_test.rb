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
end
