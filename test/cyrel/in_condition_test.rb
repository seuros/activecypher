# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class InConditionTest < ActiveSupport::TestCase
  test 'in condition with array using WHERE clause' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person') # Match node without property
    condition = Cyrel::Expression::Comparison.new(
      Cyrel.prop(:person, :country),
      :IN,
      %w[US UK] # This array will be parameterized
    )
    query = Cyrel::Query.new
                        .match(match_node)
                        .where(condition) # Use WHERE for the IN condition
                        .return_(Cyrel.prop(:person, :name))

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person)
      WHERE (person.country IN $p1)
      RETURN person.name
    CYPHER
    expected_params = { p1: %w[US UK] }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
