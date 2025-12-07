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

  # --- EXISTS Block Syntax Tests (Memgraph 3.5+) ---

  test 'exists_block with simple match' do
    # Build the path pattern outside the block
    path = Cyrel.path { node(:a) > rel(:r, :KNOWS) > node(:b, :Admin) }

    exists_expr = Cyrel.exists_block do
      match(path)
    end

    query = Cyrel::Query.new
    rendered = exists_expr.render(query)

    assert_match(/EXISTS \{ MATCH/, rendered)
    assert_match(/\(a\)-\[r:KNOWS\]->\(b:Admin\)/, rendered)
  end

  test 'exists_block with match and where' do
    path = Cyrel.path { node(:a) > rel(:r) > node(:b) }
    condition = Cyrel.prop(:b, :active) == true

    exists_expr = Cyrel.exists_block do
      match(path)
      where(condition)
    end

    query = Cyrel::Query.new
    rendered = exists_expr.render(query)

    assert_match(/EXISTS \{/, rendered)
    assert_match(/MATCH/, rendered)
    assert_match(/WHERE/, rendered)
    assert_match(/b\.active = \$p1/, rendered)
  end

  test 'exists_block in query where clause' do
    path = Cyrel.path { node(:person) > rel(:r, :MANAGES) > node(:team, :Team) }

    query = Cyrel::Query.new
                        .match(Cyrel.node(:person, :Person))
                        .where(
                          Cyrel.exists_block do
                            match(path)
                          end
                        )
                        .return_(:person)

    cypher, _params = query.to_cypher

    assert_match(/MATCH \(person:Person\)/, cypher)
    assert_match(/WHERE EXISTS \{/, cypher)
    assert_match(/MATCH \(person\)-\[r:MANAGES\]->\(team:Team\)/, cypher)
    assert_match(/RETURN person/, cypher)
  end

  test 'ExistsBlock requires Query argument' do
    assert_raises(ArgumentError) do
      Cyrel::Expression::ExistsBlock.new('not a query')
    end
  end
end
