# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstUnionTest < ActiveSupport::TestCase
    test 'union two simple queries' do
      query1 = Query.new.match(Cyrel.node(:n, :Person)).return_(:n)
      query2 = Query.new.match(Cyrel.node(:m, :Movie)).return_(:m)

      union_query = query1.union(query2)
      cypher, params = union_query.to_cypher

      expected = <<~CYPHER.strip
        MATCH (n:Person)
        RETURN n
        UNION
        MATCH (m:Movie)
        RETURN m
      CYPHER

      assert_equal expected, cypher
      assert_empty params
    end

    test 'union all with duplicates' do
      query1 = Query.new.match(Cyrel.node(:n, :Person)).return_(Cyrel.prop(:n, :name))
      query2 = Query.new.match(Cyrel.node(:m, :Movie)).return_(Cyrel.prop(:m, :title))

      union_query = query1.union_all(query2)
      cypher, params = union_query.to_cypher

      expected = <<~CYPHER.strip
        MATCH (n:Person)
        RETURN n.name
        UNION ALL
        MATCH (m:Movie)
        RETURN m.title
      CYPHER

      assert_equal expected, cypher
      assert_empty params
    end

    test 'union with parameters' do
      query1 = Query.new.match(Cyrel.node(:n, :Person)).where(Cyrel.prop(:n, :age) > 30).return_(:n)
      query2 = Query.new.match(Cyrel.node(:m, :Movie)).where(Cyrel.prop(:m, :year) > 2000).return_(:m)

      union_query = query1.union(query2)
      cypher, params = union_query.to_cypher

      expected = <<~CYPHER.strip
        MATCH (n:Person)
        WHERE (n.age > $p1)
        RETURN n
        UNION
        MATCH (m:Movie)
        WHERE (m.year > $p2)
        RETURN m
      CYPHER

      assert_equal expected, cypher
      assert_equal({ p1: 30, p2: 2000 }, params)
    end

    test 'union multiple queries' do
      query1 = Query.new.match(Cyrel.node(:n, :Person)).return_(:n)
      query2 = Query.new.match(Cyrel.node(:m, :Movie)).return_(:m)
      query3 = Query.new.match(Cyrel.node(:b, :Book)).return_(:b)

      union_query = Query.union_queries([query1, query2, query3], all: false)
      cypher, params = union_query.to_cypher

      expected = <<~CYPHER.strip
        MATCH (n:Person)
        RETURN n
        UNION
        MATCH (m:Movie)
        RETURN m
        UNION
        MATCH (b:Book)
        RETURN b
      CYPHER

      assert_equal expected, cypher
      assert_empty params
    end

    test 'union requires at least 2 queries' do
      assert_raises(ArgumentError, 'UNION requires at least 2 queries') do
        Query.union_queries([Query.new])
      end
    end
  end
end
