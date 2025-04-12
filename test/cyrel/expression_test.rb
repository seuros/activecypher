# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class ExpressionTest < ActiveSupport::TestCase
  # --- Cyrel::Expression::Literal Tests ---

  test 'literal expression rendering - String' do
    expr = Cyrel::Expression::Literal.new('hello')
    query = Cyrel::Query.new
    assert_equal '$p1', expr.render(query)
    assert_equal({ p1: 'hello' }, query.parameters)
  end

  test 'literal expression rendering - Integer' do
    expr = Cyrel::Expression::Literal.new(123)
    query = Cyrel::Query.new
    assert_equal '$p1', expr.render(query)
    assert_equal({ p1: 123 }, query.parameters)
  end

  test 'literal expression rendering - Float' do
    expr = Cyrel::Expression::Literal.new(45.67)
    query = Cyrel::Query.new
    assert_equal '$p1', expr.render(query)
    assert_equal({ p1: 45.67 }, query.parameters)
  end

  test 'literal expression rendering - Boolean true' do
    expr = Cyrel::Expression::Literal.new(true)
    query = Cyrel::Query.new
    assert_equal '$p1', expr.render(query)
    assert_equal({ p1: true }, query.parameters)
  end

  test 'literal expression rendering - Boolean false' do
    expr = Cyrel::Expression::Literal.new(false)
    query = Cyrel::Query.new
    assert_equal '$p1', expr.render(query)
    assert_equal({ p1: false }, query.parameters)
  end

  test 'literal expression rendering - Nil' do
    expr = Cyrel::Expression::Literal.new(nil)
    query = Cyrel::Query.new
    assert_equal 'NULL', expr.render(query) # NULL is special, not parameterized
    assert_empty query.parameters
  end

  test 'literal expression rendering - Array' do
    expr = Cyrel::Expression::Literal.new([1, 'two', true])
    query = Cyrel::Query.new
    assert_equal '$p1', expr.render(query)
    assert_equal({ p1: [1, 'two', true] }, query.parameters)
  end

  test 'literal expression rendering - Hash/Map' do
    expr = Cyrel::Expression::Literal.new({ key: 'value', num: 123 })
    query = Cyrel::Query.new
    assert_equal '$p1', expr.render(query)
    assert_equal({ p1: { key: 'value', num: 123 } }, query.parameters)
  end

  # --- Cyrel::Expression::PropertyAccess Tests ---

  test 'property access rendering' do
    expr = Cyrel::Expression::PropertyAccess.new(:n, :name)
    query = Cyrel::Query.new
    assert_equal 'n.name', expr.render(query)
    assert_empty query.parameters
  end

  test 'property access helper' do
    expr = Cyrel.prop(:r, :since)
    query = Cyrel::Query.new
    assert_kind_of Cyrel::Expression::PropertyAccess, expr
    assert_equal 'r.since', expr.render(query)
    assert_empty query.parameters
  end

  # --- Cyrel::Expression::Operator Tests ---

  test 'operator rendering - addition' do
    expr = Cyrel.prop(:n, :age) + 5
    query = Cyrel::Query.new
    assert_equal '(n.age + $p1)', expr.render(query)
    assert_equal({ p1: 5 }, query.parameters)
  end

  test 'operator rendering - subtraction with two properties' do
    expr = Cyrel.prop(:a, :value) - Cyrel.prop(:b, :value)
    query = Cyrel::Query.new
    assert_equal '(a.value - b.value)', expr.render(query)
    assert_empty query.parameters
  end

  test 'operator rendering - nested operators (precedence)' do
    # (a.x + 5) * b.y
    expr = (Cyrel.prop(:a, :x) + 5) * Cyrel.prop(:b, :y)
    query = Cyrel::Query.new
    assert_equal '((a.x + $p1) * b.y)', expr.render(query)
    assert_equal({ p1: 5 }, query.parameters)

    # a.x + (5 * b.y)
    expr2 = Cyrel.prop(:a, :x) + (Cyrel.prop(:b, :y) * 5) # Put expression first
    query2 = Cyrel::Query.new
    assert_equal '(a.x + (b.y * $p1))', expr2.render(query2) # Adjust expected output
    assert_equal({ p1: 5 }, query2.parameters)
  end

  # --- Cyrel::Expression::Comparison Tests ---

  test 'comparison rendering - greater than' do
    expr = Cyrel.prop(:n, :age) > 18
    query = Cyrel::Query.new
    assert_equal '(n.age > $p1)', expr.render(query)
    assert_equal({ p1: 18 }, query.parameters)
  end

  test 'comparison rendering - equals' do
    expr = Cyrel.prop(:n, :name) == 'Alice'
    query = Cyrel::Query.new
    assert_equal '(n.name = $p1)', expr.render(query)
    assert_equal({ p1: 'Alice' }, query.parameters)
  end

  test 'comparison rendering - not equals' do
    expr = Cyrel.prop(:n, :status) != 'inactive'
    query = Cyrel::Query.new
    assert_equal '(n.status <> $p1)', expr.render(query)
    assert_equal({ p1: 'inactive' }, query.parameters)
  end

  test 'comparison rendering - IS NULL' do
    expr = Cyrel::Expression::Comparison.new(Cyrel.prop(:n, :optional_prop), :"IS NULL")
    query = Cyrel::Query.new
    assert_equal '(n.optional_prop IS NULL)', expr.render(query)
    assert_empty query.parameters
  end

  test 'comparison rendering - IS NOT NULL' do
    expr = Cyrel::Expression::Comparison.new(Cyrel.prop(:n, :required_prop), :"IS NOT NULL")
    query = Cyrel::Query.new
    assert_equal '(n.required_prop IS NOT NULL)', expr.render(query)
    assert_empty query.parameters
  end

  # --- Cyrel::Expression::Logical Tests ---

  test 'logical rendering - AND' do
    expr = (Cyrel.prop(:n, :age) > 18) & (Cyrel.prop(:n, :status) == 'active')
    query = Cyrel::Query.new
    assert_equal '((n.age > $p1) AND (n.status = $p2))', expr.render(query)
    assert_equal({ p1: 18, p2: 'active' }, query.parameters)
  end

  test 'logical rendering - OR' do
    expr = (Cyrel.prop(:n, :role) == 'admin') | (Cyrel.prop(:n, :role) == 'editor')
    query = Cyrel::Query.new
    assert_equal '((n.role = $p1) OR (n.role = $p2))', expr.render(query)
    assert_equal({ p1: 'admin', p2: 'editor' }, query.parameters)
  end

  test 'logical rendering - NOT' do
    expr = Cyrel.not(Cyrel.prop(:n, :enabled) == true)
    query = Cyrel::Query.new
    assert_equal '(NOT (n.enabled = $p1))', expr.render(query)
    assert_equal({ p1: true }, query.parameters)
  end

  test 'logical rendering - complex nesting' do
    # (age > 18 AND status = 'active') OR NOT (role = 'guest')
    expr = ((Cyrel.prop(:n, :age) > 18) & (Cyrel.prop(:n, :status) == 'active')) |
           Cyrel.not(Cyrel.prop(:n, :role) == 'guest')
    query = Cyrel::Query.new
    expected = '(((n.age > $p1) AND (n.status = $p2)) OR (NOT (n.role = $p3)))'
    assert_equal expected, expr.render(query)
    assert_equal({ p1: 18, p2: 'active', p3: 'guest' }, query.parameters)
  end

  # --- Cyrel::Expression::FunctionCall Tests ---

  test 'function call rendering - id()' do
    expr = Cyrel.id(:n)
    query = Cyrel::Query.new
    # id() takes a variable directly, not an expression rendering to a variable name
    assert_equal 'id(n)', expr.render(query)
    assert_empty query.parameters
  end

  test 'function call rendering - count(*)' do
    expr = Cyrel.count(:*)
    query = Cyrel::Query.new
    assert_equal 'count(*)', expr.render(query)
    assert_empty query.parameters
  end

  test 'function call rendering - count(n)' do
    expr = Cyrel.count(Cyrel::Clause::Return::RawIdentifier.new('n')) # Pass variable identifier
    query = Cyrel::Query.new
    assert_equal 'count(n)', expr.render(query)
    assert_empty query.parameters
  end

  test 'function call rendering - count(DISTINCT n.prop)' do
    expr = Cyrel.count(Cyrel.prop(:n, :role), distinct: true)
    query = Cyrel::Query.new
    assert_equal 'count(DISTINCT n.role)', expr.render(query)
    assert_empty query.parameters
  end

  test 'function call rendering - coalesce()' do
    expr = Cyrel.coalesce(Cyrel.prop(:n, :nickname), Cyrel.prop(:n, :name), 'Unknown')
    query = Cyrel::Query.new
    assert_equal 'coalesce(n.nickname, n.name, $p1)', expr.render(query)
    assert_equal({ p1: 'Unknown' }, query.parameters)
  end

  # --- Coercion Tests ---
  test 'expression coercion - literal in comparison' do
    expr = Cyrel.prop(:n, :age) > 18 # 18 is coerced
    query = Cyrel::Query.new
    assert_equal '(n.age > $p1)', expr.render(query)
    assert_equal({ p1: 18 }, query.parameters)
  end

  test 'expression coercion - literal in operator' do
    expr = Cyrel.prop(:n, :bonus) + 100 # Put expression first
    query = Cyrel::Query.new
    assert_equal '(n.bonus + $p1)', expr.render(query) # Adjust expected output
    assert_equal({ p1: 100 }, query.parameters)
  end
end
