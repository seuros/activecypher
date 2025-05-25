# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class CallClauseTest < ActiveSupport::TestCase
  test 'call standalone procedure' do
    query = Cyrel::Query.new
                        .call_procedure('db.labels', yield_items: 'label', return_items: 'label')

    expected_cypher = 'CALL db.labels() YIELD label RETURN label'
    expected_params = {}
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'call subquery' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice' })
    outer_query = Cyrel::Query.new
                              .match(match_node)

    # Define the subquery using the block syntax
    outer_query.call_subquery do |subquery|
      # Define patterns relative to the outer scope (person alias is implicitly available)
      # Note: The current implementation doesn't automatically link aliases.
      # We need to redefine the start node within the subquery context for rendering.
      sub_person_node = Cyrel::Pattern::Node.new(:person, labels: 'Person') # Re-declare for subquery context
      friend_node = Cyrel::Pattern::Node.new(:friend, labels: 'Person')
      knows_rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', direction: :outgoing)
      sub_path = Cyrel::Pattern::Path.new([sub_person_node, knows_rel, friend_node])

      subquery.match(sub_path)
              .return_(Cyrel::Clause::With::RawExpressionString.new('collect(friend.name) AS friendNames'))
    end

    # Manually merge parameters from subquery (as noted in DSL method TODO)
    # Find the subquery clause and merge its parameters
    subquery_clause = outer_query.clauses.find do |c|
      c.is_a?(Cyrel::AST::ClauseAdapter) && c.ast_node.is_a?(Cyrel::AST::CallSubqueryNode)
    end

    # AST-based implementation - the subquery is in the ast_node
    outer_query.send(:merge_parameters!, subquery_clause.ast_node.subquery)

    # Add the final return to the outer query
    outer_query.return_(Cyrel::Clause::Return::RawIdentifier.new('person.name'),
                        Cyrel::Clause::Return::RawIdentifier.new('friendNames'))

    # Expected Cypher - Note the subquery indentation and potential parameter key shifts
    <<~CYPHER.chomp.strip
      MATCH (person:Person {name: $p1})
      CALL {
        MATCH (person:Person)-[:KNOWS]->(friend:Person)
        RETURN collect(friend.name) AS friendNames
      }
      RETURN person.name, friendNames
    CYPHER
    expected_params = { p1: 'Alice' } # Only outer query param expected here due to simple merge

    # Check parts due to clause ordering and subquery formatting
    cypher, params = outer_query.to_cypher
    assert_match(/MATCH \(person:Person \{name: \$p\d+\}\)/, cypher)
    assert_match(
      /CALL \{\s+MATCH \(person:Person\)-\[:KNOWS\]->\(friend:Person\)\s+RETURN collect\(friend.name\) AS friendNames\s+\}/m, cypher
    )
    assert_match(/RETURN person.name, friendNames/, cypher)
    assert_equal expected_params, params
  end
end
