# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstWithTest < ActiveSupport::TestCase
    test 'with single variable' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).with(:n).return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWITH n\nRETURN n", cypher
      assert_empty params
    end

    test 'with multiple variables' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).with(:n, :m).return_(:n, :m)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWITH n, m\nRETURN n, m", cypher
      assert_empty params
    end

    test 'with property access' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .with(:n, Cyrel.prop(:n, :name))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWITH n, n.name\nRETURN n", cypher
      assert_empty params
    end

    test 'with alias' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .with(:n, Cyrel::Expression::Alias.new(Cyrel.prop(:n, :name), :person_name))
                          .return_(:n, :person_name)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWITH n, n.name AS person_name\nRETURN n, person_name", cypher
      assert_empty params
    end

    test 'with distinct' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .with(:n, distinct: true)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWITH DISTINCT n\nRETURN n", cypher
      assert_empty params
    end

    test 'with where clause' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .with(:n, where: Cyrel.prop(:n, :age) > 21)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWITH n\nWHERE (n.age > $p1)\nRETURN n", cypher
      assert_equal({ p1: 21 }, params)
    end

    test 'with where clause using hash' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .with(:n, where: { active: true })
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWITH n\nWHERE (n.active = $p1)\nRETURN n", cypher
      assert_equal({ p1: true }, params)
    end

    test 'with where clause with multiple conditions' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .with(:n, where: [Cyrel.prop(:n, :age) > 21, Cyrel.prop(:n, :active) == true])
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWITH n\nWHERE (n.age > $p1) AND (n.active = $p2)\nRETURN n", cypher
      assert_equal({ p1: 21, p2: true }, params)
    end

    test 'with aggregation' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .with(Cyrel.prop(:n, :category), Cyrel.count(:n).as(:total))
                          .return_(:category, :total)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWITH n.category, count(n) AS total\nRETURN category, total", cypher
      assert_empty params
    end

    test 'with distinct and where' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .with(:n, distinct: true, where: Cyrel.prop(:n, :active) == true)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWITH DISTINCT n\nWHERE (n.active = $p1)\nRETURN n", cypher
      assert_equal({ p1: true }, params)
    end

    test 'with replaces existing with' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .with(:n)
                          .with(:m)
                          .return_(:m)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWITH m\nRETURN m", cypher
      assert_empty params
    end

    test 'complex query with with' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:p, :Person))
                          .with(
                            :p,
                            Cyrel.count(Cyrel.prop(:p, :friends)).as(:friend_count),
                            where: Cyrel.prop(:p, :age) > 21
                          )
                          .match(Cyrel::Pattern::Path.new([
                                                            Cyrel::Pattern::Node.new(:p),
                                                            Cyrel::Pattern::Relationship.new(types: ['KNOWS']),
                                                            Cyrel::Pattern::Node.new(:other)
                                                          ]))
                          .return_(:p, :friend_count, Cyrel.count(:other).as(:knows_count))

      cypher, params = query.to_cypher

      expected_cypher = <<~CYPHER.strip
        MATCH (p:Person)
        MATCH (p)-[:KNOWS]-(other)
        WITH p, count(p.friends) AS friend_count
        WHERE (p.age > $p1)
        RETURN p, friend_count, count(other) AS knows_count
      CYPHER

      assert_equal expected_cypher, cypher
      assert_equal({ p1: 21 }, params)
    end

    test 'with node structure' do
      with1 = Cyrel::AST::WithNode.new(%i[n m], distinct: false, where_conditions: [])
      with2 = Cyrel::AST::WithNode.new([:n], distinct: true, where_conditions: [Cyrel.prop(:n, :age) > 21])

      assert_equal 2, with1.items.size
      assert_equal false, with1.distinct
      assert_equal 0, with1.where_conditions.size

      assert_equal 1, with2.items.size
      assert_equal true, with2.distinct
      assert_equal 1, with2.where_conditions.size
    end
  end
end
