# frozen_string_literal: true

require 'test_helper'

class CyrelSetClausePropertyMergeTest < ActiveSupport::TestCase
  test 'set clause property merge renders plus equals' do
    props = { name: 'Alice', age: 30 }
    set_clause = Cyrel::Clause::Set.new(Cyrel.plus(:n) => props)
    query = Cyrel::Query.new

    rendered = set_clause.send(:render_assignment, set_clause.assignments.first, query)
    assert_match(/^n \+= \$p\d+$/, rendered)
    assert_equal({ p1: props }, query.parameters)
  end

  test 'set clause property merge with multiple assignments' do
    set_clause = Cyrel::Clause::Set.new(
      Cyrel.plus(:n) => { foo: 'bar' },
      Cyrel.plus(:m) => { x: 1 }
    )
    query = Cyrel::Query.new

    rendered = set_clause.render(query)
    assert_includes rendered, 'n += $p1'
    assert_includes rendered, 'm += $p2'
    assert_equal({ p1: { foo: 'bar' }, p2: { x: 1 } }, query.parameters)
  end

  test 'set clause property merge rejects non-hash' do
    assert_raises(ArgumentError) do
      Cyrel::Clause::Set.new(Cyrel.plus(:n) => 'not a hash')
    end
  end
end
