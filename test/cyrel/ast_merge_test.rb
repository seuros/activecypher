# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstMergeTest < ActiveSupport::TestCase
    test 'merge single node' do
      query = Cyrel::Query.new
                          .merge(Cyrel.node(:n))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MERGE (n)\nRETURN n", cypher
      assert_empty params
    end

    test 'merge node with labels' do
      query = Cyrel::Query.new
                          .merge(Cyrel.node(:p, :Person))
                          .return_(:p)

      cypher, params = query.to_cypher
      assert_equal "MERGE (p:Person)\nRETURN p", cypher
      assert_empty params
    end

    test 'merge node with properties' do
      query = Cyrel::Query.new
                          .merge(Cyrel.node(:n, :Person, name: 'Alice'))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MERGE (n:Person {name: $p1})\nRETURN n", cypher
      assert_equal({ p1: 'Alice' }, params)
    end

    test 'merge with on create set' do
      query = Cyrel::Query.new
                          .merge(
                            Cyrel.node(:n, :Person, name: 'Bob'),
                            on_create: [[:n, :created_at, Time.new(2024, 1, 1).to_i]]
                          )
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MERGE (n:Person {name: $p1})\nON CREATE SET n.created_at = $p2\nRETURN n", cypher
      assert_equal({ p1: 'Bob', p2: Time.new(2024, 1, 1).to_i }, params)
    end

    test 'merge with on match set' do
      query = Cyrel::Query.new
                          .merge(
                            Cyrel.node(:n, :Person, name: 'Carol'),
                            on_match: [[:n, :updated_at, Time.new(2024, 1, 1).to_i]]
                          )
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MERGE (n:Person {name: $p1})\nON MATCH SET n.updated_at = $p2\nRETURN n", cypher
      assert_equal({ p1: 'Carol', p2: Time.new(2024, 1, 1).to_i }, params)
    end

    test 'merge with both on create and on match' do
      query = Cyrel::Query.new
                          .merge(
                            Cyrel.node(:n, :Person, name: 'Dave'),
                            on_create: [[:n, :created_at, 123_456], [:n, :status, 'new']],
                            on_match: [[:n, :updated_at, 123_456], [:n, :status, 'existing']]
                          )
                          .return_(:n)

      cypher, params = query.to_cypher
      expected = "MERGE (n:Person {name: $p1})\n" \
                 "ON CREATE SET n.created_at = $p2, n.status = $p3\n" \
                 "ON MATCH SET n.updated_at = $p2, n.status = $p4\n" \
                 'RETURN n'
      assert_equal expected, cypher
      assert_equal({ p1: 'Dave', p2: 123_456, p3: 'new', p4: 'existing' }, params)
    end

    test 'merge with hash-based on create' do
      query = Cyrel::Query.new
                          .merge(
                            Cyrel.node(:n, :Person, email: 'eve@example.com'),
                            on_create: { Cyrel.prop(:n, :name) => 'Eve', Cyrel.prop(:n, :age) => 25 }
                          )
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MERGE (n:Person {email: $p1})\nON CREATE SET n.name = $p2, n.age = $p3\nRETURN n", cypher
      assert_equal({ p1: 'eve@example.com', p2: 'Eve', p3: 25 }, params)
    end

    test 'merge after match' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:p, :Person, name: 'Frank'))
                          .merge(Cyrel.node(:c, :Company, name: 'TechCorp'))
                          .return_(:p, :c)

      cypher, params = query.to_cypher
      assert_equal "MATCH (p:Person {name: $p1})\nMERGE (c:Company {name: $p2})\nRETURN p, c", cypher
      assert_equal({ p1: 'Frank', p2: 'TechCorp' }, params)
    end

    test 'multiple merge clauses' do
      query = Cyrel::Query.new
                          .merge(Cyrel.node(:a, :Person, name: 'Alice'))
                          .merge(Cyrel.node(:b, :Person, name: 'Bob'))
                          .return_(:a, :b)

      cypher, params = query.to_cypher
      assert_equal "MERGE (a:Person {name: $p1})\nMERGE (b:Person {name: $p2})\nRETURN a, b", cypher
      assert_equal({ p1: 'Alice', p2: 'Bob' }, params)
    end
  end
end
