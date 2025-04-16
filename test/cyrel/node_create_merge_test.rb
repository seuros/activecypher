# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class NodeCreateMergeTest < ActiveSupport::TestCase
  test 'create node' do
    node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice' })
    query = Cyrel::Query.new
                        .create(node)
                        .return_(:person) # Often useful to return created node

    expected_cypher = <<~CYPHER.chomp.strip
      CREATE (person:Person {name: $p1})
      RETURN person
    CYPHER
    expected_params = { p1: 'Alice' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'merge node' do
    node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice', age: 30 })
    query = Cyrel::Query.new
                        .merge(node)
                        .return_(:person) # Often useful to return merged node

    expected_cypher = <<~CYPHER.chomp.strip
      MERGE (person:Person {name: $p1, age: $p2})
      RETURN person
    CYPHER
    expected_params = { p1: 'Alice', p2: 30 }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'set properties' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice' })
    query = Cyrel::Query.new
                        .match(match_node)
                        .set(Cyrel.prop(:person, :age) => 31)
                        .return_(Cyrel.prop(:person, :age))

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person {name: $p1})
      SET person.age = $p2
      RETURN person.age
    CYPHER
    expected_params = { p1: 'Alice', p2: 31 }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'remove properties' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice' })
    query = Cyrel::Query.new
                        .match(match_node)
                        .remove(Cyrel.prop(:person, :age))
                        .return_(Cyrel.prop(:person, :name)) # Return something else

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person {name: $p1})
      REMOVE person.age
      RETURN person.name
    CYPHER
    expected_params = { p1: 'Alice' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'detach delete' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice' })
    query = Cyrel::Query.new
                        .match(match_node)
                        .detach_delete(:person)
    # No RETURN after DELETE

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person {name: $p1})
      DETACH DELETE person
    CYPHER
    expected_params = { p1: 'Alice' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
