# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class WithClauseTest < ActiveSupport::TestCase
  test 'with clause followed by where' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { active: true })

    # Define the items for the WITH clause
    with_person = Cyrel::Clause::Return::RawIdentifier.new('person') # Pass the variable
    with_count = Cyrel::Clause::With::RawExpressionString.new('count(*) AS cnt') # Aggregation with alias

    # Define the WHERE condition to apply *after* WITH
    where_after_with = Cyrel::Expression::Comparison.new(
      Cyrel::Clause::Return::RawIdentifier.new('cnt'), # Referencing the alias from WITH
      :>,
      10
    )

    query = Cyrel::Query.new
                        .match(match_node)
                        .with(with_person, with_count, where: where_after_with)
                        .return_(Cyrel.prop(:person, :name))

    <<~CYPHER.chomp.strip
      MATCH (person:Person {active: $p1})
      WITH person, count(*) AS cnt
      WHERE (cnt > $p2)
      RETURN person.name
    CYPHER
    expected_params = { p1: true, p2: 10 }

    # Check parts due to clause ordering
    cypher, params = query.to_cypher
    assert_match(/MATCH \(person:Person \{active: \$p\d+\}\)/, cypher)
    assert_match(/WITH person, count\(\*\) AS cnt/, cypher)
    assert_match(/WHERE \(cnt > \$p\d+\)/, cypher)
    assert_match(/RETURN person.name/, cypher)
    assert_equal expected_params, params
  end
end
