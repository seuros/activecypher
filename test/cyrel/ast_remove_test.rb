# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstRemoveTest < ActiveSupport::TestCase
    test 'remove single property' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .remove(Cyrel.prop(:n, :age))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nREMOVE n.age\nRETURN n", cypher
      assert_empty params
    end

    test 'remove multiple properties' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .remove(Cyrel.prop(:n, :age), Cyrel.prop(:n, :email))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nREMOVE n.age, n.email\nRETURN n", cypher
      assert_empty params
    end

    test 'remove single label' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .remove(%i[n Inactive])
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nREMOVE n:Inactive\nRETURN n", cypher
      assert_empty params
    end

    test 'remove multiple labels' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .remove(%i[n Temp], %i[n Archived])
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nREMOVE n:Temp, n:Archived\nRETURN n", cypher
      assert_empty params
    end

    test 'remove properties and labels together' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .remove(Cyrel.prop(:n, :temp_data), %i[n Temporary])
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nREMOVE n.temp_data, n:Temporary\nRETURN n", cypher
      assert_empty params
    end

    test 'remove after set' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .set(Cyrel.prop(:n, :updated_at) => Time.at(1_234_567_890))
                          .remove(Cyrel.prop(:n, :old_field))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:Person)\nSET n.updated_at = $p1\nREMOVE n.old_field\nRETURN n", cypher
      assert_equal({ p1: Time.at(1_234_567_890) }, params)
    end

    test 'remove with where clause' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :User))
                          .where(Cyrel.prop(:n, :status) == 'deleted')
                          .remove(%i[n Active], Cyrel.prop(:n, :last_login))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:User)\nWHERE (n.status = $p1)\nREMOVE n:Active, n.last_login\nRETURN n", cypher
      assert_equal({ p1: 'deleted' }, params)
    end

    test 'remove from multiple nodes' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:a))
                          .match(Cyrel.node(:b))
                          .remove(Cyrel.prop(:a, :temp), Cyrel.prop(:b, :temp))
                          .return_(:a, :b)

      cypher, params = query.to_cypher
      assert_equal "MATCH (a)\nMATCH (b)\nREMOVE a.temp, b.temp\nRETURN a, b", cypher
      assert_empty params
    end

    test 'complex remove with multiple clauses' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:p, :Person))
                          .where(Cyrel.prop(:p, :migrated) == true)
                          .set(Cyrel.prop(:p, :migration_complete) => true)
                          .remove(Cyrel.prop(:p, :old_id), %i[p Legacy])
                          .return_(Cyrel.function(:count, :p))

      cypher, params = query.to_cypher
      assert_equal "MATCH (p:Person)\nWHERE (p.migrated = $p1)\nSET p.migration_complete = $p1\nREMOVE p.old_id, p:Legacy\nRETURN count($p2)", cypher
      assert_equal({ p1: true, p2: :p }, params)
    end
  end
end
