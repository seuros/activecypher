# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstCreateTest < ActiveSupport::TestCase
    test 'create single node' do
      query = Cyrel::Query.new
                          .create(Cyrel.node(:n))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "CREATE (n)\nRETURN n", cypher
      assert_empty params
    end

    test 'create node with labels' do
      query = Cyrel::Query.new
                          .create(Cyrel.node(:p, :Person))
                          .return_(:p)

      cypher, params = query.to_cypher
      assert_equal "CREATE (p:Person)\nRETURN p", cypher
      assert_empty params
    end

    test 'create node with properties' do
      query = Cyrel::Query.new
                          .create(Cyrel.node(:n, :Person, name: 'Alice', age: 30))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "CREATE (n:Person {name: $p1, age: $p2})\nRETURN n", cypher
      assert_equal({ p1: 'Alice', p2: 30 }, params)
    end

    test 'create multiple nodes' do
      query = Cyrel::Query.new
                          .create(Cyrel.node(:a, :Person))
                          .create(Cyrel.node(:b, :Company))
                          .return_(:a, :b)

      cypher, params = query.to_cypher
      assert_equal "CREATE (a:Person)\nCREATE (b:Company)\nRETURN a, b", cypher
      assert_empty params
    end

    test 'create after match' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:p, :Person, name: 'Alice'))
                          .create(Cyrel.node(:c, :Company, name: 'TechCorp'))
                          .return_(:p, :c)

      cypher, params = query.to_cypher
      assert_equal "MATCH (p:Person {name: $p1})\nCREATE (c:Company {name: $p2})\nRETURN p, c", cypher
      assert_equal({ p1: 'Alice', p2: 'TechCorp' }, params)
    end

    test 'create with where clause' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:p, :Person))
                          .where(Cyrel.prop(:p, :age) > 21)
                          .create(Cyrel.node(:a, :Adult))
                          .return_(:p, :a)

      cypher, params = query.to_cypher
      assert_equal "MATCH (p:Person)\nWHERE (p.age > $p1)\nCREATE (a:Adult)\nRETURN p, a", cypher
      assert_equal({ p1: 21 }, params)
    end

    test 'create with set clause' do
      query = Cyrel::Query.new
                          .create(Cyrel.node(:n, :Person))
                          .set(Cyrel.prop(:n, :name) => 'Bob', Cyrel.prop(:n, :age) => 25)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "CREATE (n:Person)\nSET n.name = $p1, n.age = $p2\nRETURN n", cypher
      assert_equal({ p1: 'Bob', p2: 25 }, params)
    end

    test 'create anonymous node' do
      query = Cyrel::Query.new
                          .create(Cyrel.node)
                          .return_(Cyrel.function(:count, Cyrel::Functions::ASTERISK))

      cypher, params = query.to_cypher
      assert_equal "CREATE ()\nRETURN count(*)", cypher
      assert_empty params
    end

    test 'create multiple labels' do
      query = Cyrel::Query.new
                          .create(Cyrel.node(:n, :Person, :Employee, name: 'Carol'))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "CREATE (n:Person:Employee {name: $p1})\nRETURN n", cypher
      assert_equal({ p1: 'Carol' }, params)
    end
  end
end
