# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstWhereTest < ActiveSupport::TestCase
    test 'where with simple comparison' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).where(Cyrel.prop(:n, :age) > 21).return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE (n.age > $p1)\nRETURN n", cypher
      assert_equal({ p1: 21 }, params)
    end

    test 'where with hash conditions' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).where(name: 'Alice', age: 30).return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE (n.name = $p1) AND (n.age = $p2)\nRETURN n", cypher
      assert_equal({ p1: 'Alice', p2: 30 }, params)
    end

    test 'where with single hash condition' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).where(name: 'Bob').return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE (n.name = $p1)\nRETURN n", cypher
      assert_equal({ p1: 'Bob' }, params)
    end

    test 'multiple where calls are combined with AND' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .where(Cyrel.prop(:n, :age) > 21)
                          .where(Cyrel.prop(:n, :active) == true)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE (n.age > $p1) AND (n.active = $p2)\nRETURN n", cypher
      assert_equal({ p1: 21, p2: true }, params)
    end

    test 'where with string comparison' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .where(Cyrel::Expression::Comparison.new(Cyrel.prop(:n, :name), :STARTS_WITH, 'A'))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE (n.name STARTS_WITH $p1)\nRETURN n", cypher
      assert_equal({ p1: 'A' }, params)
    end

    test 'where with IN operator' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .where(Cyrel::Expression::Comparison.new(Cyrel.prop(:n, :status), :IN, %w[active pending]))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE (n.status IN $p1)\nRETURN n", cypher
      assert_equal({ p1: %w[active pending] }, params)
    end

    test 'where with IS NULL' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .where(Cyrel::Expression::Comparison.new(Cyrel.prop(:n, :deleted_at), :'IS NULL'))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE (n.deleted_at IS NULL)\nRETURN n", cypher
      assert_empty params
    end

    test 'where with logical OR' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .where((Cyrel.prop(:n, :age) < 18) | (Cyrel.prop(:n, :age) > 65))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE ((n.age < $p1) OR (n.age > $p2))\nRETURN n", cypher
      assert_equal({ p1: 18, p2: 65 }, params)
    end

    test 'where with logical AND using &' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .where((Cyrel.prop(:n, :age) >= 18) & (Cyrel.prop(:n, :age) <= 65))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE ((n.age >= $p1) AND (n.age <= $p2))\nRETURN n", cypher
      assert_equal({ p1: 18, p2: 65 }, params)
    end

    test 'where with EXISTS predicate' do
      rel = Cyrel::Pattern::Relationship.new(types: ['KNOWS'])
      friend = Cyrel::Pattern::Node.new(:friend)
      path = Cyrel::Pattern::Path.new([Cyrel::Pattern::Node.new(:n), rel, friend])

      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .where(Cyrel.exists(path))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE EXISTS((n)-[:KNOWS]-(friend))\nRETURN n", cypher
      assert_empty params
    end

    test 'where with NOT' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .where(Cyrel.not(Cyrel.prop(:n, :active) == true))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE (NOT (n.active = $p1))\nRETURN n", cypher
      assert_equal({ p1: true }, params)
    end

    test 'complex where with multiple conditions' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:p, :Person))
                          .where(name: 'Alice')
                          .where(Cyrel.prop(:p, :age) > 21)
                          .where((Cyrel.prop(:p, :status) == 'active') | (Cyrel.prop(:p, :role) == 'admin'))
                          .return_(:p)

      cypher, params = query.to_cypher
      assert_equal "MATCH (p:Person)\nWHERE (p.name = $p1) AND (p.age > $p2) AND ((p.status = $p3) OR (p.role = $p4))\nRETURN p", cypher
      assert_equal({ p1: 'Alice', p2: 21, p3: 'active', p4: 'admin' }, params)
    end

    test 'where preserves clause ordering' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .return_(:n)
                          .order_by(%i[n asc])
                          .where(Cyrel.prop(:n, :active) == true)
                          .skip(10)
                          .limit(5)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE (n.active = $p1)\nRETURN n\nORDER BY n\nSKIP $p2\nLIMIT $p3", cypher
      assert_equal({ p1: true, p2: 10, p3: 5 }, params)
    end

    test 'empty where conditions are ignored' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).where.return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n", cypher
      assert_empty params
    end

    test 'where node structure' do
      where1 = Cyrel::AST::WhereNode.new([Cyrel.prop(:n, :age) > 21])
      where2 = Cyrel::AST::WhereNode.new([Cyrel.prop(:n, :age) > 21, Cyrel.prop(:n, :active) == true])
      where3 = Cyrel::AST::WhereNode.new([])

      # Test basic structure
      assert_equal 1, where1.conditions.size
      assert_equal 2, where2.conditions.size
      assert_equal 0, where3.conditions.size

      # Test that conditions are expressions
      assert where1.conditions.first.is_a?(Cyrel::Expression::Comparison)
    end
  end
end
