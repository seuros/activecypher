# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class QueryMergingTest < ActiveSupport::TestCase
  test 'merge simple match queries' do
    query1 = Cyrel::Query.new.match(Cyrel::Pattern::Node.new(:n, labels: 'Person'))
    query2 = Cyrel::Query.new.match(Cyrel::Pattern::Node.new(:m, labels: 'Movie'))

    query1.merge!(query2)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (n:Person)
      MATCH (m:Movie)
    CYPHER
    expected_params = {}
    assert_equal [expected_cypher, expected_params], query1.to_cypher
  end

  test 'merge queries with where clauses' do
    query1 = Cyrel::Query.new
                         .match(Cyrel::Pattern::Node.new(:n, labels: 'Person'))
                         .where(Cyrel.prop(:n, :age) > 30)
    query2 = Cyrel::Query.new
                         .where(Cyrel.prop(:n, :city) == 'London') # Refers to alias from query1

    query1.merge!(query2)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (n:Person)
      WHERE (n.age > $p1) AND (n.city = $p2)
    CYPHER
    # Parameters are re-registered in the target query
    expected_params = { p1: 30, p2: 'London' }
    assert_equal [expected_cypher, expected_params], query1.to_cypher
  end

  test 'merge queries with parameters' do
    query1 = Cyrel::Query.new.match(Cyrel::Pattern::Node.new(:n, labels: 'Person', properties: { name: 'Alice' }))
    query2 = Cyrel::Query.new.match(Cyrel::Pattern::Node.new(:m, labels: 'Movie', properties: { title: 'Inception' }))

    query1.merge!(query2)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (n:Person {name: $p1})
      MATCH (m:Movie {title: $p2})
    CYPHER
    # Parameters are re-registered, keys might change but values should be present
    expected_params = { p1: 'Alice', p2: 'Inception' }
    assert_equal [expected_cypher, expected_params], query1.to_cypher
    assert_equal 2, query1.parameters.size
    assert_equal %w[Alice Inception], query1.parameters.values.sort_by(&:to_s)
  end

  test 'merge overwrites order by' do
    query1 = Cyrel::Query.new
                         .match(Cyrel::Pattern::Node.new(:n, labels: 'Person'))
                         .order_by([Cyrel.prop(:n, :name), :asc])
    query2 = Cyrel::Query.new
                         .order_by([Cyrel.prop(:n, :age), :desc])

    query1.merge!(query2)

    <<~CYPHER.chomp.strip
      MATCH (n:Person)
      ORDER BY n.age DESC
    CYPHER
    expected_params = {}
    cypher, params = query1.to_cypher
    assert_match(/MATCH \(n:Person\)/, cypher)
    assert_match(/ORDER BY n.age DESC/, cypher)
    refute_match(/ORDER BY n.name ASC/, cypher)
    assert_equal expected_params, params
  end

  test 'merge overwrites skip' do
    query1 = Cyrel::Query.new
                         .match(Cyrel::Pattern::Node.new(:n, labels: 'Person'))
                         .skip(10)
    query2 = Cyrel::Query.new
                         .skip(20)

    query1.merge!(query2)

    <<~CYPHER.chomp.strip
      MATCH (n:Person)
      SKIP $p1
    CYPHER
    expected_params = { p1: 20 }
    cypher, params = query1.to_cypher
    assert_match(/MATCH \(n:Person\)/, cypher)
    assert_match(/SKIP \$p\d+/, cypher)
    assert_equal expected_params, params
  end

  test 'merge overwrites limit' do
    query1 = Cyrel::Query.new
                         .match(Cyrel::Pattern::Node.new(:n, labels: 'Person'))
                         .limit(5)
    query2 = Cyrel::Query.new
                         .limit(10)

    query1.merge!(query2)

    <<~CYPHER.chomp.strip
      MATCH (n:Person)
      LIMIT $p1
    CYPHER
    expected_params = { p1: 10 }
    cypher, params = query1.to_cypher
    assert_match(/MATCH \(n:Person\)/, cypher)
    assert_match(/LIMIT \$p\d+/, cypher)
    assert_equal expected_params, params
  end

  test 'merge appends set clauses' do
    query1 = Cyrel::Query.new
                         .match(Cyrel::Pattern::Node.new(:n, labels: 'Person'))
                         .set(Cyrel.prop(:n, :age) => 30)
    query2 = Cyrel::Query.new
                         .set(Cyrel.prop(:n, :city) => 'Berlin')

    query1.merge!(query2)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (n:Person)
      SET n.age = $p1
      SET n.city = $p2
    CYPHER
    expected_params = { p1: 30, p2: 'Berlin' }
    assert_equal [expected_cypher, expected_params], query1.to_cypher
  end

  test 'merge raises error on alias conflict' do
    query1 = Cyrel::Query.new.match(Cyrel::Pattern::Node.new(:n, labels: 'Person'))
    query2 = Cyrel::Query.new.match(Cyrel::Pattern::Node.new(:n, labels: 'Movie')) # Same alias, different label

    assert_raises(Cyrel::AliasConflictError) do
      query1.merge!(query2)
    end
  end

  test 'merge succeeds with same alias and same labels' do
    query1 = Cyrel::Query.new.match(Cyrel::Pattern::Node.new(:n, labels: 'Person'))
    query2 = Cyrel::Query.new.match(Cyrel::Pattern::Node.new(:n, labels: 'Person')) # Same alias, same label

    assert_nothing_raised do
      query1.merge!(query2)
    end

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (n:Person)
      MATCH (n:Person)
    CYPHER
    assert_equal [expected_cypher, {}], query1.to_cypher
  end

  test 'merge succeeds with same alias and no labels' do
    query1 = Cyrel::Query.new.match(Cyrel::Pattern::Node.new(:n))
    query2 = Cyrel::Query.new.match(Cyrel::Pattern::Node.new(:n)) # Same alias, no labels

    assert_nothing_raised do
      query1.merge!(query2)
    end
    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (n)
      MATCH (n)
    CYPHER
    assert_equal [expected_cypher, {}], query1.to_cypher
  end

  # Optional: Test merging when one query defines labels and the other doesn't for the same alias.
  # Current implementation allows this, might need adjustment based on desired behavior.
  # test "merge succeeds with same alias and labels vs no labels" do ... end
end
