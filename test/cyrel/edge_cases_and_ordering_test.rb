# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class EdgeCasesAndOrderingTest < ActiveSupport::TestCase
  test 'Aliasing a Node in MATCH' do
    # Define node with alias 'a'
    match_node = Cyrel::Pattern::Node.new(:a, labels: 'Person', properties: { name: 'Alice' })
    query = Cyrel::Query.new
                        .match(match_node)
                        .return_(Cyrel.prop(:a, :name)) # Use the alias 'a' in return

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (a:Person {name: $p1})
      RETURN a.name
    CYPHER
    expected_params = { p1: 'Alice' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
