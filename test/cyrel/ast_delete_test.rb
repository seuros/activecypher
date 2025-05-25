# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstDeleteTest < ActiveSupport::TestCase
    test 'delete single node' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .delete_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nDELETE n", cypher
      assert_empty params
    end

    test 'delete multiple nodes' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:a))
                          .match(Cyrel.node(:b))
                          .delete_(:a, :b)

      cypher, params = query.to_cypher
      assert_equal "MATCH (a)\nMATCH (b)\nDELETE a, b", cypher
      assert_empty params
    end

    test 'delete with where clause' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .where(Cyrel.prop(:n, :age) < 18)
                          .delete_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:Person)\nWHERE (n.age < $p1)\nDELETE n", cypher
      assert_equal({ p1: 18 }, params)
    end

    test 'detach delete single node' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .detach_delete(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nDETACH DELETE n", cypher
      assert_empty params
    end

    test 'detach delete multiple nodes' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:a))
                          .match(Cyrel.node(:b))
                          .detach_delete(:a, :b)

      cypher, params = query.to_cypher
      assert_equal "MATCH (a)\nMATCH (b)\nDETACH DELETE a, b", cypher
      assert_empty params
    end

    test 'delete after create' do
      query = Cyrel::Query.new
                          .create(Cyrel.node(:temp, :TempNode))
                          .delete_(:temp)

      cypher, params = query.to_cypher
      assert_equal "CREATE (temp:TempNode)\nDELETE temp", cypher
      assert_empty params
    end

    test 'delete with return clause' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .delete_(:n)
                          .return_(Cyrel.function(:count, Cyrel::Functions::ASTERISK))

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:Person)\nDELETE n\nRETURN count(*)", cypher
      assert_empty params
    end

    test 'complex delete with multiple clauses' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:p, :Person))
                          .where(Cyrel.prop(:p, :status) == 'inactive')
                          .optional_match(Cyrel.node(:c, :Content))
                          .where(Cyrel.prop(:c, :owner_id) == Cyrel.prop(:p, :id))
                          .detach_delete(:p, :c)

      cypher, params = query.to_cypher
      assert_equal "MATCH (p:Person)\nOPTIONAL MATCH (c:Content)\nWHERE (p.status = $p1) AND (c.owner_id = p.id)\nDETACH DELETE p, c", cypher
      assert_equal({ p1: 'inactive' }, params)
    end

    test 'delete ordering is correct' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .set(Cyrel.prop(:n, :deleted) => true)
                          .delete_(:n)
                          .return_(Cyrel.function(:count, Cyrel::Functions::ASTERISK))

      cypher, params = query.to_cypher
      # SET and DELETE both have priority 40, so they maintain insertion order
      assert_equal "MATCH (n)\nSET n.deleted = $p1\nDELETE n\nRETURN count(*)", cypher
      assert_equal({ p1: true }, params)
    end
  end
end
