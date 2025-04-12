# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class CreatingAndMergingNodesTest < ActiveSupport::TestCase
  test 'CREATE Node' do
    node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice' })
    query = Cyrel::Query.new
                        .create(node)
    # No RETURN clause in original test

    expected_cypher = <<~CYPHER.chomp.strip
      CREATE (person:Person {name: $p1})
    CYPHER
    expected_params = { p1: 'Alice' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'MERGE Node' do
    node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice', age: 30 })
    query = Cyrel::Query.new
                        .merge(node)
    # No RETURN clause in original test

    expected_cypher = <<~CYPHER.chomp.strip
      MERGE (person:Person {name: $p1, age: $p2})
    CYPHER
    expected_params = { p1: 'Alice', p2: 30 }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
