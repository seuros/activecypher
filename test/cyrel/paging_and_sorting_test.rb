# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class PagingAndSortingTest < ActiveSupport::TestCase
  test 'ORDER BY, SKIP, and LIMIT' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { country: 'US' })
    query = Cyrel::Query.new
                        .match(match_node)
                        .return_(Cyrel::Clause::With::RawExpressionString.new('person.name AS name')) # Use Raw for AS
                        .order_by([Cyrel.prop(:person, :age), :desc])
                        .skip(5)
                        .limit(5)

    <<~CYPHER.chomp.strip
      MATCH (person:Person {country: $p1})
      RETURN person.name AS name
      ORDER BY person.age DESC
      SKIP $p2
      LIMIT $p3
    CYPHER
    expected_params = { p1: 'US', p2: 5 } # Updated for parameter reuse

    # Check parts due to clause ordering
    cypher, params = query.to_cypher
    assert_match(/MATCH \(person:Person \{country: \$p\d+\}\)/, cypher)
    assert_match(/RETURN person.name AS name/, cypher)
    assert_match(/ORDER BY person.age DESC/, cypher)
    assert_match(/SKIP \$p\d+/, cypher)
    assert_match(/LIMIT \$p\d+/, cypher)
    assert_equal expected_params, params
  end
end
