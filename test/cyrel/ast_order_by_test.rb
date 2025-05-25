# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstOrderByTest < ActiveSupport::TestCase
    test 'order by single column ascending' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).order_by(%i[n asc])

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nORDER BY n", cypher
      assert_empty params
    end

    test 'order by single column descending' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).order_by(%i[n desc])

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nORDER BY n DESC", cypher
      assert_empty params
    end

    test 'order by with property access' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).order_by([Cyrel.prop(:n, :name), :asc])

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nORDER BY n.name", cypher
      assert_empty params
    end

    test 'order by multiple columns' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).order_by(
        [Cyrel.prop(:n, :age), :desc],
        [Cyrel.prop(:n, :name), :asc]
      )

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nORDER BY n.age DESC, n.name", cypher
      assert_empty params
    end

    test 'order by with hash syntax' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).order_by(
        Cyrel.prop(:n, :age) => :desc,
        Cyrel.prop(:n, :name) => :asc
      )

      cypher, params = query.to_cypher
      # Hash order is preserved in Ruby 1.9+
      assert_equal "MATCH (n)\nRETURN n\nORDER BY n.age DESC, n.name", cypher
      assert_empty params
    end

    test 'order by replaces existing order by' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .return_(:n)
                          .order_by([Cyrel.prop(:n, :age), :asc])
                          .order_by([Cyrel.prop(:n, :name), :desc])

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nORDER BY n.name DESC", cypher
      assert_empty params
    end

    test 'order by with skip and limit' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .return_(:n)
                          .order_by([Cyrel.prop(:n, :age), :desc])
                          .skip(10)
                          .limit(5)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nORDER BY n.age DESC\nSKIP $p1\nLIMIT $p2", cypher
      assert_equal({ p1: 10, p2: 5 }, params)
    end

    test 'order by with function expression' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .return_(:n)
                          .order_by([Cyrel.count(:n), :desc])

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nORDER BY count(n) DESC", cypher
      assert_empty params
    end

    test 'order by with nil direction defaults to ascending' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).order_by([:n, nil])

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nORDER BY n", cypher
      assert_empty params
    end

    test 'order by with parameter expression' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).order_by([5, :asc])

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nORDER BY $p1", cypher
      assert_equal({ p1: 5 }, params)
    end

    test 'complex query with order by' do
      node = Cyrel::Pattern::Node.new(:p, labels: 'Person', properties: { active: true })

      query = Cyrel::Query.new
                          .match(node)
                          .where(Cyrel.prop(:p, :age) > 18)
                          .return_(:p, Cyrel::Expression::Alias.new(Cyrel.prop(:p, :name), :person_name))
                          .order_by(
                            [Cyrel.prop(:p, :age), :desc],
                            [Cyrel.prop(:p, :name), :asc]
                          )
                          .skip(20)
                          .limit(10)

      cypher, params = query.to_cypher

      expected_cypher = <<~CYPHER.strip
        MATCH (p:Person {active: $p1})
        WHERE (p.age > $p2)
        RETURN p, p.name AS person_name
        ORDER BY p.age DESC, p.name
        SKIP $p3
        LIMIT $p4
      CYPHER

      assert_equal expected_cypher, cypher
      assert_equal({ p1: true, p2: 18, p3: 20, p4: 10 }, params)
    end

    test 'order by caching works correctly' do
      order1 = Cyrel::AST::OrderByNode.new([%i[n asc]])
      order2 = Cyrel::AST::OrderByNode.new([%i[n asc]])

      adapter1 = Cyrel::AST::ClauseAdapter.new(order1)
      adapter2 = Cyrel::AST::ClauseAdapter.new(order2)

      query = Cyrel::Query.new

      # Should use cache for same value
      result1 = adapter1.render(query)
      result2 = adapter2.render(query)

      assert_equal result1, result2
    end

    test 'order by node equality' do
      order1 = Cyrel::AST::OrderByNode.new([%i[n asc], %i[m desc]])
      order2 = Cyrel::AST::OrderByNode.new([%i[n asc], %i[m desc]])
      order3 = Cyrel::AST::OrderByNode.new([%i[n desc]])

      assert_equal order1, order2
      refute_equal order1, order3
    end
  end
end
