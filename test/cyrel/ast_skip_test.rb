# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstSkipTest < ActiveSupport::TestCase
    test 'skip with integer' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).skip(10)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nSKIP $p1", cypher
      assert_equal({ p1: 10 }, params)
    end

    test 'skip with parameter' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).skip(:skip_count)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nSKIP $p1", cypher
      assert_equal({ p1: :skip_count }, params)
    end

    test 'skip with expression' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).skip(5)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nSKIP $p1", cypher
      assert_equal({ p1: 5 }, params)
    end

    test 'skip replaces existing skip' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).skip(10).skip(20)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nSKIP $p1", cypher
      assert_equal({ p1: 20 }, params)
    end

    test 'skip with limit maintains order' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).skip(10).limit(5)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nSKIP $p1\nLIMIT $p2", cypher
      assert_equal({ p1: 10, p2: 5 }, params)
    end

    test 'limit then skip maintains order' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).limit(5).skip(10)

      cypher, params = query.to_cypher
      # Cypher standard order is SKIP before LIMIT regardless of query building order
      assert_equal "MATCH (n)\nRETURN n\nSKIP $p1\nLIMIT $p2", cypher
      assert_equal({ p1: 10, p2: 5 }, params)
    end

    test 'skip with order by' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).order_by(%i[n asc]).skip(10)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nORDER BY n\nSKIP $p1", cypher
      assert_equal({ p1: 10 }, params)
    end

    test 'skip with string amount' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).skip('10')

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nSKIP $p1", cypher
      assert_equal({ p1: '10' }, params)
    end

    test 'skip with zero' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).skip(0)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nSKIP $p1", cypher
      assert_equal({ p1: 0 }, params)
    end

    test 'skip with nil becomes parameter' do
      query = Cyrel::Query.new.match(Cyrel.node(:n)).return_(:n).skip(nil)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n\nSKIP $p1", cypher
      assert_equal({ p1: nil }, params)
    end

    test 'complex query with skip' do
      node1 = Cyrel::Pattern::Node.new(:n, properties: { name: 'Alice' })
      rel = Cyrel::Pattern::Relationship.new(types: [], alias_name: :r)
      node2 = Cyrel::Pattern::Node.new(:m)
      path = Cyrel::Pattern::Path.new([node1, rel, node2])

      query = Cyrel::Query.new
                          .match(node1)
                          .match(path)
                          .where(Cyrel.prop(:n, :age) > 21)
                          .return_(:n, :m, Cyrel.count(:r).as(:relationship_count))
                          .order_by([Cyrel.prop(:n, :age), :desc])
                          .skip(20)
                          .limit(10)

      cypher, params = query.to_cypher

      expected_cypher = <<~CYPHER.strip
        MATCH (n {name: $p1})
        MATCH (n {name: $p1})-[r]-(m)
        WHERE (n.age > $p2)
        RETURN n, m, count(r) AS relationship_count
        ORDER BY n.age DESC
        SKIP $p3
        LIMIT $p4
      CYPHER

      assert_equal expected_cypher, cypher
      assert_equal({ p1: 'Alice', p2: 21, p3: 20, p4: 10 }, params)
    end

    test 'skip caching works correctly' do
      skip1 = Cyrel::AST::SkipNode.new(10)
      skip2 = Cyrel::AST::SkipNode.new(10)

      adapter1 = Cyrel::AST::ClauseAdapter.new(skip1)
      adapter2 = Cyrel::AST::ClauseAdapter.new(skip2)

      query = Cyrel::Query.new

      # Should use cache for same value
      result1 = adapter1.render(query)
      result2 = adapter2.render(query)

      assert_equal result1, result2
    end

    test 'skip node equality' do
      skip1 = Cyrel::AST::SkipNode.new(10)
      skip2 = Cyrel::AST::SkipNode.new(10)
      skip3 = Cyrel::AST::SkipNode.new(20)

      assert_equal skip1, skip2
      refute_equal skip1, skip3
    end
  end
end
