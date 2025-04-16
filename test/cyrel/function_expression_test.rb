# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class FunctionExpressionTest < ActiveSupport::TestCase
  test 'function expression in return with alias' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice' })
    # Cypher functions are often case-insensitive, but let's assume toUpper exists or use toString as an example
    # Using toString as it's defined in our helpers
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

  test 'count function' do
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

  test 'average function' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person')
    # Use the Cyrel.avg helper and RawExpressionString for alias
    avg_expr = Cyrel.avg(Cyrel.prop(:person, :age))
    return_expr = Cyrel::Clause::With::RawExpressionString.new(
      "#{avg_expr.render(Cyrel::Query.new)} AS averageAge"
    )

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

  test 'using function helper directly in return' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person')
    # This won't automatically alias, but tests the function helper
    query = Cyrel::Query.new
                        .match(match_node)
                        .return_(Cyrel.count(:*)) # Use helper

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person)
      RETURN count(*)
    CYPHER
    expected_params = {}
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
