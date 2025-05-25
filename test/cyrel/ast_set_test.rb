# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstSetTest < ActiveSupport::TestCase
    test 'set single property' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .set(Cyrel.prop(:n, :name) => 'Alice')
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nSET n.name = $p1\nRETURN n", cypher
      assert_equal({ p1: 'Alice' }, params)
    end

    test 'set multiple properties' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .set(
                            Cyrel.prop(:n, :name) => 'Bob',
                            Cyrel.prop(:n, :age) => 30
                          )
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nSET n.name = $p1, n.age = $p2\nRETURN n", cypher
      assert_equal({ p1: 'Bob', p2: 30 }, params)
    end

    test 'set variable to properties hash' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .set(n: { name: 'Charlie', age: 25, active: true })
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nSET n = $p1\nRETURN n", cypher
      assert_equal({ p1: { name: 'Charlie', age: 25, active: true } }, params)
    end

    test 'set with += operator' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .set(Cyrel.plus(:n) => { updated_at: Time.at(1_234_567_890), version: 2 })
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nSET n += $p1\nRETURN n", cypher
      assert_equal({ p1: { updated_at: Time.at(1_234_567_890), version: 2 } }, params)
    end

    test 'set labels' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .set([[:n, 'Person'], [:n, 'Employee']])
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nSET n:Person, n:Employee\nRETURN n", cypher
      assert_empty params
    end

    test 'multiple set clauses are merged' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .set(Cyrel.prop(:n, :name) => 'Alice')
                          .set(Cyrel.prop(:n, :age) => 30)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nSET n.name = $p1, n.age = $p2\nRETURN n", cypher
      assert_equal({ p1: 'Alice', p2: 30 }, params)
    end

    test 'set with expression values' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .match(Cyrel.node(:m))
                          .set(Cyrel.prop(:n, :name) => Cyrel.prop(:m, :name))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nMATCH (m)\nSET n.name = m.name\nRETURN n", cypher
      assert_empty params
    end

    test 'set with nil value' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .set(Cyrel.prop(:n, :deleted_at) => nil)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nSET n.deleted_at = $p1\nRETURN n", cypher
      assert_equal({ p1: nil }, params)
    end

    test 'complex set with create' do
      query = Cyrel::Query.new
                          .create(Cyrel.node(:n))
                          .set(
                            n: { name: 'New Node', created_at: Time.at(1_234_567_890) },
                            Cyrel.prop(:n, :version) => 1
                          )
                          .set([[:n, 'Active']])
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "CREATE (n)\nSET n = $p1, n.version = $p2, n:Active\nRETURN n", cypher
      assert_equal({ p1: { name: 'New Node', created_at: Time.at(1_234_567_890) }, p2: 1 }, params)
    end

    test 'set preserves clause ordering' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .where(Cyrel.prop(:n, :active) == true)
                          .set(Cyrel.prop(:n, :updated_at) => Time.at(1_234_567_890))
                          .return_(:n)
                          .order_by([Cyrel.prop(:n, :name), :asc])

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nWHERE (n.active = $p1)\nSET n.updated_at = $p2\nRETURN n\nORDER BY n.name", cypher
      assert_equal({ p1: true, p2: Time.at(1_234_567_890) }, params)
    end

    test 'set node structure' do
      assignments1 = [[:property, Cyrel.prop(:n, :name), 'Alice']]
      assignments2 = [[:label, :n, 'Person'], [:label, :n, 'Active']]

      set1 = Cyrel::AST::SetNode.new(assignments1)
      set2 = Cyrel::AST::SetNode.new(assignments2)

      assert_equal 1, set1.assignments.size
      assert_equal :property, set1.assignments.first[0]

      assert_equal 2, set2.assignments.size
      assert_equal :label, set2.assignments.first[0]
    end

    test 'error on invalid property assignment value' do
      assert_raises(ArgumentError) do
        Cyrel::Query.new.set(n: 'not a hash')
      end
    end

    test 'error on invalid plus assignment value' do
      assert_raises(ArgumentError) do
        Cyrel::Query.new.set(Cyrel.plus(:n) => 'not a hash')
      end
    end
  end
end
