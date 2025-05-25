# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstMatchTest < ActiveSupport::TestCase
    test 'basic node match' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nRETURN n", cypher
      assert_empty params
    end

    test 'node match with labels' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:p, :Person))
                          .return_(:p)

      cypher, params = query.to_cypher
      assert_equal "MATCH (p:Person)\nRETURN p", cypher
      assert_empty params
    end

    test 'node match with properties' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person, name: 'Alice'))
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:Person {name: $p1})\nRETURN n", cypher
      assert_equal({ p1: 'Alice' }, params)
    end

    test 'relationship pattern match' do
      query = Cyrel::Query.new
                          .match(Cyrel.path { node(:a) > rel(:r, :KNOWS) > node(:b) }) # rubocop:disable Lint/MultipleComparison
                          .return_(:a, :b)

      cypher, params = query.to_cypher
      assert_equal "MATCH (a)-[r:KNOWS]->(b)\nRETURN a, b", cypher
      assert_empty params
    end

    test 'bidirectional relationship pattern' do
      query = Cyrel::Query.new
                          .match(Cyrel.path { node(:a) - rel(:r, :KNOWS) - node(:b) })
                          .return_(:a, :b)

      cypher, params = query.to_cypher
      assert_equal "MATCH (a)-[r:KNOWS]-(b)\nRETURN a, b", cypher
      assert_empty params
    end

    test 'path variable assignment' do
      query = Cyrel::Query.new
                          .match(Cyrel.path { node(:a) > rel(:r) > node(:b) }, path_variable: :p) # rubocop:disable Lint/MultipleComparison
                          .return_(:p)

      cypher, params = query.to_cypher
      assert_equal "MATCH p = (a)-[r]->(b)\nRETURN p", cypher
      assert_empty params
    end

    test 'optional match' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .optional_match(Cyrel.path { node(:n) > rel(:r, :LIKES) > node(:m) }) # rubocop:disable Lint/MultipleComparison
                          .return_(:n, :m)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nOPTIONAL MATCH (n)-[r:LIKES]->(m)\nRETURN n, m", cypher
      assert_empty params
    end

    test 'multiple match clauses' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .match(Cyrel.node(:m, :Company))
                          .return_(:n, :m)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:Person)\nMATCH (m:Company)\nRETURN n, m", cypher
      assert_empty params
    end

    test 'complex path pattern' do
      query = Cyrel::Query.new
                          .match(Cyrel.path do
                                   node(:a, :Person) > rel(:r1, :WORKS_AT) > node(:c, :Company) < rel(:r2, :EMPLOYS) < node(:b, :Person) # rubocop:disable Lint/MultipleComparison
                                 end)
                          .return_(:a, :b, :c)

      cypher, params = query.to_cypher
      assert_equal "MATCH (a:Person)-[r1:WORKS_AT]->(c:Company)<-[r2:EMPLOYS]-(b:Person)\nRETURN a, b, c", cypher
      assert_empty params
    end

    test 'match with where clause' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .where(Cyrel.prop(:n, :age) > 21)
                          .return_(:n)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n:Person)\nWHERE (n.age > $p1)\nRETURN n", cypher
      assert_equal({ p1: 21 }, params)
    end

    test 'anonymous node match' do
      query = Cyrel::Query.new
                          .match(Cyrel.node)
                          .return_(Cyrel.function(:count, Cyrel::Functions::ASTERISK))

      cypher, params = query.to_cypher
      assert_equal "MATCH ()\nRETURN count(*)", cypher
      assert_empty params
    end

    test 'relationship with properties' do
      query = Cyrel::Query.new
                          .match(Cyrel.path { node(:a) > rel(:r, :KNOWS, since: 2020) > node(:b) }) # rubocop:disable Lint/MultipleComparison
                          .return_(:a, :b, :r)

      cypher, params = query.to_cypher
      assert_equal "MATCH (a)-[r:KNOWS {since: $p1}]->(b)\nRETURN a, b, r", cypher
      assert_equal({ p1: 2020 }, params)
    end

    test 'variable length relationship' do
      query = Cyrel::Query.new
                          .match(Cyrel.path { node(:a) > rel(:r, :KNOWS, length: 1..3) > node(:b) }) # rubocop:disable Lint/MultipleComparison
                          .return_(:a, :b)

      cypher, params = query.to_cypher
      assert_equal "MATCH (a)-[r:KNOWS*1..3]->(b)\nRETURN a, b", cypher
      assert_empty params
    end

    test 'optional match with path variable' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n))
                          .optional_match(Cyrel.path { node(:n) > rel && rel > node(:m) }, path_variable: :p)
                          .return_(:n, :p)

      cypher, params = query.to_cypher
      assert_equal "MATCH (n)\nOPTIONAL MATCH p = (n)-->(m)\nRETURN n, p", cypher
      assert_empty params
    end
  end
end
