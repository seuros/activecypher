# frozen_string_literal: true

require 'test_helper'
require 'cyrel' # Ensure Cyrel and its components are loaded

class PatternTest < ActiveSupport::TestCase
  # --- Cyrel::Pattern::Node Tests ---

  test 'node pattern rendering - alias only' do
    node = Cyrel::Pattern::Node.new(:n)
    query = Cyrel::Query.new # Needed for render context
    assert_equal '(n)', node.render(query)
    assert_empty query.parameters
  end

  test 'node pattern rendering - alias and label' do
    node = Cyrel::Pattern::Node.new(:n, labels: 'Person')
    query = Cyrel::Query.new
    assert_equal '(n:Person)', node.render(query) # Expect standard Cypher syntax
    assert_empty query.parameters
  end

  test 'node pattern rendering - alias and multiple labels' do
    node = Cyrel::Pattern::Node.new(:n, labels: %w[Person Developer])
    query = Cyrel::Query.new
    assert_equal '(n:Person:Developer)', node.render(query) # Expect standard Cypher syntax
    assert_empty query.parameters
  end

  test 'node pattern rendering - alias, label, and properties' do
    node = Cyrel::Pattern::Node.new(:n, labels: 'Person', properties: { name: 'Alice', age: 30 })
    query = Cyrel::Query.new
    assert_equal '(n:Person {name: $p1, age: $p2})', node.render(query) # Expect standard Cypher syntax
    assert_equal({ p1: 'Alice', p2: 30 }, query.parameters)
  end

  test 'node pattern rendering - alias and properties only' do
    node = Cyrel::Pattern::Node.new(:n, properties: { status: 'active' })
    query = Cyrel::Query.new
    assert_equal '(n {status: $p1})', node.render(query)
    assert_equal({ p1: 'active' }, query.parameters)
  end

  test 'node pattern rendering - label only (requires alias)' do
    # While Cypher allows (:Label), our Node class requires an alias for reference
    node = Cyrel::Pattern::Node.new(:_unnamed, labels: 'Person') # Use a placeholder alias
    query = Cyrel::Query.new
    assert_equal '(_unnamed:Person)', node.render(query) # Expect standard Cypher syntax
  end

  # --- Cyrel::Pattern::Relationship Tests ---

  test 'relationship pattern rendering - outgoing, type only' do
    rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', direction: :outgoing)
    query = Cyrel::Query.new
    assert_equal '-[:KNOWS]->', rel.render(query)
    assert_empty query.parameters
  end

  test 'relationship pattern rendering - incoming, type only' do
    rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', direction: :incoming)
    query = Cyrel::Query.new
    assert_equal '<-[:KNOWS]-', rel.render(query)
    assert_empty query.parameters
  end

  test 'relationship pattern rendering - both directions, type only' do
    rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', direction: :both)
    query = Cyrel::Query.new
    assert_equal '-[:KNOWS]-', rel.render(query)
    assert_empty query.parameters
  end

  test 'relationship pattern rendering - alias and type' do
    rel = Cyrel::Pattern::Relationship.new(alias_name: :r, types: 'KNOWS', direction: :outgoing)
    query = Cyrel::Query.new
    assert_equal '-[r :KNOWS]->', rel.render(query)
    assert_empty query.parameters
  end

  test 'relationship pattern rendering - multiple types' do
    rel = Cyrel::Pattern::Relationship.new(types: %w[KNOWS WORKS_WITH], direction: :outgoing)
    query = Cyrel::Query.new
    assert_equal '-[:KNOWS|WORKS_WITH]->', rel.render(query)
    assert_empty query.parameters
  end

  test 'relationship pattern rendering - type and properties' do
    rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', properties: { since: 2020 }, direction: :outgoing)
    query = Cyrel::Query.new
    assert_equal '-[:KNOWS {since: $p1}]->', rel.render(query)
    assert_equal({ p1: 2020 }, query.parameters)
  end

  test 'relationship pattern rendering - alias, type, properties' do
    rel = Cyrel::Pattern::Relationship.new(alias_name: :r, types: 'KNOWS', properties: { since: 2020 },
                                           direction: :outgoing)
    query = Cyrel::Query.new
    assert_equal '-[r :KNOWS {since: $p1}]->', rel.render(query)
    assert_equal({ p1: 2020 }, query.parameters)
  end

  test 'relationship pattern rendering - variable length *' do
    rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', length: '*', direction: :outgoing)
    query = Cyrel::Query.new
    assert_equal '-[:KNOWS*]->', rel.render(query)
  end

  test 'relationship pattern rendering - variable length exact' do
    rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', length: 3, direction: :outgoing)
    query = Cyrel::Query.new
    assert_equal '-[:KNOWS*3]->', rel.render(query)
  end

  test 'relationship pattern rendering - variable length range' do
    rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', length: 1..5, direction: :outgoing)
    query = Cyrel::Query.new
    assert_equal '-[:KNOWS*1..5]->', rel.render(query)
  end

  test 'relationship pattern rendering - variable length open range start' do
    rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', length: 1.., direction: :outgoing)
    query = Cyrel::Query.new
    assert_equal '-[:KNOWS*1..]->', rel.render(query)
  end

  test 'relationship pattern rendering - variable length open range end' do
    rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', length: ..5, direction: :outgoing)
    query = Cyrel::Query.new
    assert_equal '-[:KNOWS*..5]->', rel.render(query)
  end

  test 'relationship pattern rendering - alias, type, properties, length' do
    rel = Cyrel::Pattern::Relationship.new(alias_name: :r, types: 'KNOWS', properties: { active: true },
                                           length: '*1..', direction: :outgoing)
    query = Cyrel::Query.new
    assert_equal '-[r :KNOWS*1.. {active: $p1}]->', rel.render(query)
    assert_equal({ p1: true }, query.parameters)
  end

  # --- Cyrel::Pattern::Path Tests ---

  test 'path pattern rendering - simple node-rel-node' do
    n1 = Cyrel::Pattern::Node.new(:n, labels: 'Person')
    r = Cyrel::Pattern::Relationship.new(alias_name: :r, types: 'KNOWS', direction: :outgoing)
    n2 = Cyrel::Pattern::Node.new(:m, labels: 'Person')
    path = Cyrel::Pattern::Path.new([n1, r, n2])
    query = Cyrel::Query.new
    assert_equal '(n:Person)-[r :KNOWS]->(m:Person)', path.render(query) # Expect standard Cypher syntax
    assert_empty query.parameters
  end

  test 'path pattern rendering - with properties' do
    n1 = Cyrel::Pattern::Node.new(:n, labels: 'Person', properties: { name: 'Alice' })
    r = Cyrel::Pattern::Relationship.new(alias_name: :r, types: 'KNOWS', properties: { since: 2021 },
                                         direction: :outgoing)
    n2 = Cyrel::Pattern::Node.new(:m, labels: 'Person', properties: { name: 'Bob' })
    path = Cyrel::Pattern::Path.new([n1, r, n2])
    query = Cyrel::Query.new
    assert_equal '(n:Person {name: $p1})-[r :KNOWS {since: $p2}]->(m:Person {name: $p3})', path.render(query) # Corrected expectation
    assert_equal({ p1: 'Alice', p2: 2021, p3: 'Bob' }, query.parameters) # Expect standard Cypher syntax
  end

  test 'path pattern rendering - longer path' do
    n1 = Cyrel::Pattern::Node.new(:a)
    r1 = Cyrel::Pattern::Relationship.new(types: 'REL1', direction: :outgoing)
    n2 = Cyrel::Pattern::Node.new(:b)
    r2 = Cyrel::Pattern::Relationship.new(types: 'REL2', direction: :incoming)
    n3 = Cyrel::Pattern::Node.new(:c)
    path = Cyrel::Pattern::Path.new([n1, r1, n2, r2, n3])
    query = Cyrel::Query.new
    assert_equal '(a)-[:REL1]->(b)<-[:REL2]-(c)', path.render(query)
    assert_empty query.parameters
  end

  test 'path pattern validation - must start with node' do
    r = Cyrel::Pattern::Relationship.new(types: 'KNOWS')
    n = Cyrel::Pattern::Node.new(:n)
    assert_raises(ArgumentError) { Cyrel::Pattern::Path.new([r, n]) }
  end

  test 'path pattern validation - must alternate node/rel' do
    n1 = Cyrel::Pattern::Node.new(:n)
    n2 = Cyrel::Pattern::Node.new(:m)
    r = Cyrel::Pattern::Relationship.new(types: 'KNOWS')
    assert_raises(ArgumentError) { Cyrel::Pattern::Path.new([n1, n2]) }
    assert_raises(ArgumentError) { Cyrel::Pattern::Path.new([n1, r, r, n2]) }
  end
end
