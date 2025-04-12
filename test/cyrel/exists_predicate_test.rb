# frozen_string_literal: true

require 'test_helper'

class ExistsPredicateTest < ActiveSupport::TestCase
  test 'exists predicate in WHERE clause' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person')

    # Define the pattern for the EXISTS predicate
    # Note: The original test used (:Person) which implies an anonymous node.
    # We'll create a pattern starting from the matched 'person' alias.
    exists_start_node = Cyrel::Pattern::Node.new(:person) # Reference outer alias - needs alias
    exists_rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', direction: :outgoing)
    exists_end_node = Cyrel::Pattern::Node.new(:_friend, labels: 'Person') # Anonymous related node needs an alias
    exists_pattern = Cyrel::Pattern::Path.new([exists_start_node, exists_rel, exists_end_node])

    # Create the EXISTS expression
    exists_condition = Cyrel.exists(exists_pattern)

    # Build the query
    query = Cyrel::Query.new
                        .match(match_node)
                        .where(exists_condition)
                        .return_(Cyrel.prop(:person, :name))

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person)
      WHERE EXISTS((person)-[:KNOWS]->(_friend:Person))
      RETURN person.name
    CYPHER
    expected_params = {}

    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
