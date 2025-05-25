# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstCallTest < ActiveSupport::TestCase
    test 'call procedure without arguments' do
      query = Cyrel::Query.new
                          .call_procedure('db.labels')

      cypher, params = query.to_cypher
      assert_equal 'CALL db.labels', cypher
      assert_empty params
    end

    test 'call procedure with arguments' do
      query = Cyrel::Query.new
                          .call_procedure('apoc.create.node', arguments: [%w[Person Employee], { name: 'Alice' }])

      cypher, params = query.to_cypher
      assert_equal 'CALL apoc.create.node($p1, $p2)', cypher
      assert_equal({ p1: %w[Person Employee], p2: { name: 'Alice' } }, params)
    end

    test 'call procedure with yield' do
      query = Cyrel::Query.new
                          .call_procedure('db.labels', yield_items: [:label])
                          .return_(:label)

      cypher, params = query.to_cypher
      assert_equal "CALL db.labels YIELD label\nRETURN label", cypher
      assert_empty params
    end

    test 'call procedure with multiple yield items' do
      query = Cyrel::Query.new
                          .call_procedure('db.schema.visualization', yield_items: %i[nodes relationships])
                          .return_(:nodes, :relationships)

      cypher, params = query.to_cypher
      assert_equal "CALL db.schema.visualization YIELD nodes, relationships\nRETURN nodes, relationships", cypher
      assert_empty params
    end

    test 'call procedure with yield and aliases' do
      query = Cyrel::Query.new
                          .call_procedure('db.propertyKeys', yield_items: { propertyKey: :key })
                          .return_(:key)

      cypher, params = query.to_cypher
      assert_equal "CALL db.propertyKeys YIELD propertyKey AS key\nRETURN key", cypher
      assert_empty params
    end

    test 'call subquery simple' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .call_subquery do |sq|
        sq.match(Cyrel.node(:m, :Movie))
          .return_(:m)
      end
        .return_(:n, :m)

      cypher, params = query.to_cypher
      expected = "MATCH (n:Person)\nCALL {\n  MATCH (m:Movie)\n  RETURN m\n}\nRETURN n, m"
      assert_equal expected, cypher
      assert_empty params
    end

    test 'call subquery with parameters' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:p, :Person))
                          .call_subquery do |sq|
        sq.match(Cyrel.node(:f, :Friend))
          .where(Cyrel.prop(:f, :age) > 21)
          .return_(:f)
      end
        .return_(:p, :f)

      cypher, params = query.to_cypher
      expected = "MATCH (p:Person)\nCALL {\n  MATCH (f:Friend)\n  WHERE (f.age > $p1)\n  RETURN f\n}\nRETURN p, f"
      assert_equal expected, cypher
      assert_equal({ p1: 21 }, params)
    end

    test 'complex call with match and where' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .call_procedure('apoc.neighbors.tohop',
                                          arguments: [:n, 'KNOWS', 2],
                                          yield_items: [:node])
                          .where(Cyrel.prop(:node, :active) == true)
                          .return_(:n, :node)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:Person)\nCALL apoc.neighbors.tohop($p1, $p2, $p3) YIELD node\nWHERE (node.active = $p4)\nRETURN n, node", cypher
      assert_equal({ p1: :n, p2: 'KNOWS', p3: 2, p4: true }, params)
    end

    test 'call ordering is correct' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .call_procedure('db.labels', yield_items: [:label])
                          .with(:n, :label)
                          .return_(:n, :label)

      cypher, params = query.to_cypher
      # CALL has priority 15, WITH has 20
      assert_equal "MATCH (n)\nCALL db.labels YIELD label\nWITH n, label\nRETURN n, label", cypher
      assert_empty params
    end
  end
end
