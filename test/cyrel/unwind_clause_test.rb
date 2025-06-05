# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class UnwindClauseTest < ActiveSupport::TestCase
    test 'unwind with literal array' do
      query = Cyrel::Query.new
                          .unwind([1, 2, 3], :x)
                          .return_(:x)

      cypher, params = query.to_cypher
      assert_equal "UNWIND [1, 2, 3] AS x\nRETURN x", cypher
      assert_empty params
    end

    test 'unwind with parameter' do
      query = Cyrel::Query.new
                          .unwind(:items, :item)
                          .return_(:item)

      cypher, params = query.to_cypher
      assert_equal "UNWIND $p1 AS item\nRETURN item", cypher
      assert_equal({ p1: :items }, params)
    end

    test 'unwind with expression' do
      # Using range expression: range(1, 5)
      query = Cyrel::Query.new
                          .unwind(Cyrel.function(:range, 1, 5), :num)
                          .return_(:num)

      expected_cypher = <<~CYPHER.chomp.strip
        UNWIND range($p1, $p2) AS num
        RETURN num
      CYPHER
      expected_params = { p1: 1, p2: 5 }
      cypher, params = query.to_cypher
      assert_equal expected_cypher, cypher
      assert_equal expected_params, params
    end

    test 'unwind in complex query' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .unwind(%i[friend colleague family], :rel_type)
                          .create(Cyrel::Pattern::Path.new([
                                                             Cyrel::Pattern::Node.new(:n),
                                                             Cyrel::Pattern::Relationship.new(alias_name: :r, types: :rel_type, direction: :outgoing),
                                                             Cyrel::Pattern::Node.new(:m, labels: [:Person])
                                                           ]))
                          .return_(:n, :rel_type, :m)

      cypher, = query.to_cypher
      expected = "MATCH (n:Person)\nUNWIND ['friend', 'colleague', 'family'] AS rel_type\nCREATE (n)-[r:rel_type]->(m:Person)\nRETURN n, rel_type, m"
      assert_equal expected, cypher
    end

    test 'unwind with nested array' do
      query = Cyrel::Query.new
                          .unwind([[1, 2], [3, 4]], :pair)
                          .unwind(:pair, :value)
                          .return_(:value)

      cypher, params = query.to_cypher
      assert_equal "UNWIND [[1, 2], [3, 4]] AS pair\nUNWIND $p1 AS value\nRETURN value", cypher
      assert_equal({ p1: :pair }, params)
    end

    test 'unwind preserves clause order' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Node))
                          .where(Cyrel::Expression::Comparison.new(
                                   Cyrel::Expression::PropertyAccess.new(:n, :active),
                                   :'=',
                                   true
                                 ))
                          .unwind(:tags, :tag)
                          .create(Cyrel::Pattern::Path.new([
                                                             Cyrel::Pattern::Node.new(:n),
                                                             Cyrel::Pattern::Relationship.new(types: 'TAGGED', direction: :outgoing),
                                                             Cyrel::Pattern::Node.new(:t, labels: [:Tag], properties: { name: :tag })
                                                           ]))
                          .return_(:n, :t)

      cypher, params = query.to_cypher
      expected = "MATCH (n:Node)\nWHERE (n.active = $p1)\nUNWIND $p2 AS tag\nCREATE (n)-[:TAGGED]->(t:Tag {name: $p3})\nRETURN n, t"
      assert_equal expected, cypher
      assert_equal({ p1: true, p2: :tags, p3: :tag }, params)
    end

    test 'unwind with property access' do
      query = Cyrel::Query.new
                          .match(Cyrel.node(:n, :Person))
                          .unwind(Cyrel::Expression::PropertyAccess.new(:n, :hobbies), :hobby)
                          .return_(:n, :hobby)

      cypher, = query.to_cypher
      assert_equal "MATCH (n:Person)\nUNWIND n.hobbies AS hobby\nRETURN n, hobby", cypher
    end

    test 'multiple unwind clauses' do
      query = Cyrel::Query.new
                          .unwind(:categories, :category)
                          .unwind(:subcategories, :subcategory)
                          .create(Cyrel.node(:c, :Category, name: :category))
                          .create(Cyrel.node(:s, :Subcategory, name: :subcategory))
                          .create(Cyrel::Pattern::Path.new([
                                                             Cyrel::Pattern::Node.new(:c),
                                                             Cyrel::Pattern::Relationship.new(types: 'HAS_SUBCATEGORY', direction: :outgoing),
                                                             Cyrel::Pattern::Node.new(:s)
                                                           ]))

      cypher, params = query.to_cypher
      expected = "UNWIND $p1 AS category\nUNWIND $p2 AS subcategory\nCREATE (c:Category {name: $p3})\nCREATE (s:Subcategory {name: $p4})\nCREATE (c)-[:HAS_SUBCATEGORY]->(s)"
      assert_equal expected, cypher
      assert_equal({ p1: :categories, p2: :subcategories, p3: :category, p4: :subcategory }, params)
    end

    test 'unwind integrates with existing query building' do
      # Test that unwind works seamlessly with the existing clause-based system
      query = Cyrel::Query.new
      query = query.match(Cyrel.node(:p, :Person))
      query = query.where(Cyrel::Expression::Comparison.new(
                            Cyrel::Expression::PropertyAccess.new(:p, :age),
                            :'=',
                            30
                          ))
      query = query.unwind(:skills, :skill)
      query = query.merge(Cyrel.node(:s, :Skill, name: :skill))
      query = query.merge(Cyrel::Pattern::Path.new([
                                                     Cyrel::Pattern::Node.new(:p),
                                                     Cyrel::Pattern::Relationship.new(types: 'HAS_SKILL', direction: :outgoing),
                                                     Cyrel::Pattern::Node.new(:s)
                                                   ]))
      query = query.return_(:p, :s)

      cypher, params = query.to_cypher
      expected = "MATCH (p:Person)\nWHERE (p.age = $p1)\nUNWIND $p2 AS skill\nMERGE (s:Skill {name: $p3})\nMERGE (p)-[:HAS_SKILL]->(s)\nRETURN p, s"
      assert_equal expected, cypher
      assert_equal({ p1: 30, p2: :skills, p3: :skill }, params)
    end
  end
end
