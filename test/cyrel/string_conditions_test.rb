# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class StringConditionsTest < ActiveSupport::TestCase
  test 'contains condition' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person')
    condition = Cyrel::Expression::Comparison.new(
      Cyrel.prop(:person, :name),
      :CONTAINS,
      'Smith' # This will be parameterized
    )
    query = Cyrel::Query.new
                        .match(match_node)
                        .where(condition)
                        .return_(Cyrel.prop(:person, :name))

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person)
      WHERE (person.name CONTAINS $p1)
      RETURN person.name
    CYPHER
    expected_params = { p1: 'Smith' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'starts with condition' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person')
    condition = Cyrel::Expression::Comparison.new(
      Cyrel.prop(:person, :name),
      :'STARTS WITH',
      'Al'
    )
    query = Cyrel::Query.new
                        .match(match_node)
                        .where(condition)
                        .return_(Cyrel.prop(:person, :name))

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person)
      WHERE (person.name STARTS WITH $p1)
      RETURN person.name
    CYPHER
    expected_params = { p1: 'Al' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'ends with condition' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person')
    condition = Cyrel::Expression::Comparison.new(
      Cyrel.prop(:person, :name),
      :'ENDS WITH',
      'son'
    )
    query = Cyrel::Query.new
                        .match(match_node)
                        .where(condition)
                        .return_(Cyrel.prop(:person, :name))

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person)
      WHERE (person.name ENDS WITH $p1)
      RETURN person.name
    CYPHER
    expected_params = { p1: 'son' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
