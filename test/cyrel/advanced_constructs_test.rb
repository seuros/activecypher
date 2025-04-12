# frozen_string_literal: true

require 'test_helper'
require 'cyrel'
require 'cyrel/expression/pattern_comprehension' # Ensure loaded

class AdvancedConstructsTest < ActiveSupport::TestCase
  test 'Pattern Comprehension in RETURN' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person')

    # Define the pattern for the comprehension
    # Note: Aliases inside the comprehension are local to it.
    # The 'person' alias here refers to the outer matched node.
    comp_start_node = Cyrel::Pattern::Node.new(:person) # Reference outer alias
    comp_rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', direction: :outgoing)
    comp_friend_node = Cyrel::Pattern::Node.new(:friend, labels: 'Person') # Local alias 'friend'
    comprehension_pattern = Cyrel::Pattern::Path.new([comp_start_node, comp_rel, comp_friend_node])

    # Define the projection expression within the comprehension
    projection = Cyrel.prop(:friend, :name) # Project the friend's name

    # Create the comprehension expression
    comprehension_expr = Cyrel::Expression::PatternComprehension.new(comprehension_pattern, projection)

    # Build the main query - .as() not implemented, use RawExpressionString workaround
    # query = Cyrel::Query.new
    #                      .match(match_node)
    #                      .return_(Cyrel.prop(:person, :name).as("name"),
    #                               comprehension_expr.as("friends"))

    # Using RawExpressionString for aliased returns for now
    query_raw = Cyrel::Query.new
                            .match(match_node)
                            .return_(Cyrel::Clause::With::RawExpressionString.new('person.name AS name'),
                                     Cyrel::Clause::With::RawExpressionString.new("#{comprehension_expr.render(Cyrel::Query.new)} AS friends"))

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person)
      RETURN person.name AS name, [(person)-[:KNOWS]->(friend:Person) | friend.name] AS friends
    CYPHER
    expected_params = {}

    assert_equal [expected_cypher, expected_params], query_raw.to_cypher
  end

  # Removed duplicate CALL tests, already covered in call_clause_test.rb
end
