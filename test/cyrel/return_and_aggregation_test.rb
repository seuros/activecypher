# frozen_string_literal: true

require 'test_helper'
require 'cyrel'
require 'cyrel/functions' # Explicitly require

class ReturnAndAggregationTest < ActiveSupport::TestCase
  test 'Return with a Function Expression and Alias' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice' })
    # Using toString as an example function from our helpers
    return_expr = Cyrel::Clause::With::RawExpressionString.new('toString(person.name) AS nameString')

    query = Cyrel::Query.new
                        .match(match_node)
                        .return_(return_expr)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person {name: $p1})
      RETURN toString(person.name) AS nameString
    CYPHER
    expected_params = { p1: 'Alice' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'Aggregation – Count Function with Alias' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person')
    return_expr = Cyrel::Clause::With::RawExpressionString.new('count(*) AS totalCount')

    query = Cyrel::Query.new
                        .match(match_node) # Match all persons
                        .return_(return_expr)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person)
      RETURN count(*) AS totalCount
    CYPHER
    expected_params = {}
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'Aggregation – Average Function with Alias' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person')
    # Use the Cyrel.avg helper and RawExpressionString for alias
    avg_expr_rendered = Cyrel.avg(Cyrel.prop(:person, :age)).render(Cyrel::Query.new) # Render avg expression
    return_expr = Cyrel::Clause::With::RawExpressionString.new("#{avg_expr_rendered} AS averageAge")

    query = Cyrel::Query.new
                        .match(match_node) # Match all persons
                        .return_(return_expr)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person)
      RETURN avg(person.age) AS averageAge
    CYPHER
    expected_params = {}
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
