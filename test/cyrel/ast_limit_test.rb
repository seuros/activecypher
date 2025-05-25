# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class ASTLimitTest < ActiveSupport::TestCase
    test 'limit with integer creates AST node' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .limit(10)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:Person)\nRETURN n\nLIMIT $p1", cypher
      assert_equal({ p1: 10 }, params)
    end

    test 'limit with parameter symbol' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .limit(:count)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:Person)\nRETURN n\nLIMIT $p1", cypher
      assert_equal({ p1: :count }, params)
    end

    test 'limit replaces existing limit' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .limit(10)
                          .limit(5)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:Person)\nRETURN n\nLIMIT $p1", cypher
      assert_equal({ p1: 5 }, params)
    end

    test 'limit works with skip' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .skip(20)
                          .limit(10)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:Person)\nRETURN n\nSKIP $p1\nLIMIT $p2", cypher
      assert_equal({ p1: 20, p2: 10 }, params)
    end

    test 'limit maintains proper clause order' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .where(Cyrel::Expression::Comparison.new(
                                   Cyrel::Expression::PropertyAccess.new(:n, :age),
                                   :>,
                                   18
                                 ))
                          .return_(:n)
                          .order_by([Cyrel::Expression::PropertyAccess.new(:n, :name), :asc])
                          .skip(10)
                          .limit(5)

      cypher, params = query.to_cypher
      expected = <<~CYPHER.strip
        MATCH (n:Person)
        WHERE (n.age > $p1)
        RETURN n
        ORDER BY n.name
        SKIP $p2
        LIMIT $p3
      CYPHER
      assert_equal expected, cypher
      assert_equal({ p1: 18, p2: 10, p3: 5 }, params)
    end

    test 'AST limit node equality' do
      node1 = AST::LimitNode.new(10)
      node2 = AST::LimitNode.new(10)
      node3 = AST::LimitNode.new(20)

      assert_equal node1, node2
      refute_equal node1, node3
    end
  end
end
