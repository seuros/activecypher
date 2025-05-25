# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstReturnTest < ActiveSupport::TestCase
    test 'return single variable' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n", cypher
      assert_empty params
    end

    test 'return multiple variables' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n, :m, :r)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n, m, r", cypher
      assert_empty params
    end

    test 'return with property access' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n, Cyrel.prop(:n, :name))

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n, n.name", cypher
      assert_empty params
    end

    test 'return with alias' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .return_(:n, Cyrel::Expression::Alias.new(Cyrel.prop(:n, :name), :person_name))

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n, n.name AS person_name", cypher
      assert_empty params
    end

    test 'return with function' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .return_(Cyrel.count(:n))

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN count(n)", cypher
      assert_empty params
    end

    test 'return with function and alias' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .return_(Cyrel.count(:n).as(:total))

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN count(n) AS total", cypher
      assert_empty params
    end

    test 'return distinct' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n, distinct: true)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN DISTINCT n", cypher
      assert_empty params
    end

    test 'return distinct with multiple items' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .return_(Cyrel.prop(:n, :category), Cyrel.prop(:n, :status), distinct: true)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN DISTINCT n.category, n.status", cypher
      assert_empty params
    end

    test 'return with literal value' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n, 42, 'hello')

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n, $p1, $p2", cypher
      assert_equal({ p1: 42, p2: 'hello' }, params)
    end

    test 'return replaces existing return' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .return_(:n)
                          .return_(:m)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN m", cypher
      assert_empty params
    end

    test 'complex return with multiple expressions' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:p, :Person))
                          .where(Cyrel.prop(:p, :age) > 21)
                          .return_(
                            :p,
                            Cyrel::Expression::Alias.new(Cyrel.prop(:p, :name), :person_name),
                            Cyrel.prop(:p, :age),
                            Cyrel.count(Cyrel.prop(:p, :friends)).as(:friend_count)
                          )
                          .order_by([Cyrel.prop(:p, :age), :desc])

      cypher, params = query.to_cypher

      expected_cypher = <<~CYPHER.strip
        MATCH (p:Person)
        WHERE (p.age > $p1)
        RETURN p, p.name AS person_name, p.age, count(p.friends) AS friend_count
        ORDER BY p.age DESC
      CYPHER

      assert_equal expected_cypher, cypher
      assert_equal({ p1: 21 }, params)
    end

    test 'return with aggregation preserves order' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .return_(Cyrel.prop(:n, :category), Cyrel.count(:n).as(:total))
                          .order_by([Cyrel.count(:n), :desc])

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n.category, count(n) AS total\nORDER BY count(n) DESC", cypher
      assert_empty params
    end

    test 'return node structure' do
      return1 = Cyrel::AST::ReturnNode.new(%i[n m])
      return2 = Cyrel::AST::ReturnNode.new([:n], distinct: true)

      assert_equal 2, return1.items.size
      assert_equal false, return1.distinct

      assert_equal 1, return2.items.size
      assert_equal true, return2.distinct
    end
  end
end
