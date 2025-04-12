# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class PathVariableTest < ActiveSupport::TestCase
  test 'path variable assignment in MATCH' do
    # Define the pattern
    node1 = Cyrel::Pattern::Node.new(:person1, labels: 'Person', properties: { name: 'Alice' })
    rel = Cyrel::Pattern::Relationship.new(types: 'KNOWS', direction: :outgoing)
    node2 = Cyrel::Pattern::Node.new(:person2, labels: 'Person') # Use distinct alias
    path_pattern = Cyrel::Pattern::Path.new([node1, rel, node2])

    # Build the query, assigning 'p' to the path in the match clause
    query = Cyrel::Query.new
                        .match(path_pattern, path_variable: :p)
                        .return_(:p) # Return the path variable

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH p = (person1:Person {name: $p1})-[:KNOWS]->(person2:Person)
      RETURN p
    CYPHER
    expected_params = { p1: 'Alice' }

    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
