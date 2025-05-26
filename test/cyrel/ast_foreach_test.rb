# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstForeachTest < ActiveSupport::TestCase
    test 'foreach with SET update' do
      query = Query.new
                   .match(Cyrel.node(:n))
                   .foreach(:x, %i[a b c]) do |sub|
                     sub.set(Cyrel.prop(:n, :x) => :x)
                   end
                   .return_(:n)

      cypher, params = query.to_cypher

      expected = <<~CYPHER.strip
        MATCH (n)
        FOREACH (x IN $p1 | SET n.x = x)
        RETURN n
      CYPHER

      assert_equal expected, cypher
      assert_equal({ p1: %i[a b c] }, params)
    end

    test 'foreach with CREATE' do
      query = Query.new
                   .match(Cyrel.node(:n))
                   .foreach(:name, Cyrel.prop(:n, :names)) do |sub|
                     sub.create(Cyrel.node(:m, :Person, name: :name))
                   end
                   .return_(:n)

      cypher, params = query.to_cypher

      expected = <<~CYPHER.strip
        MATCH (n)
        FOREACH (name IN n.names | CREATE (m:Person {name: name}))
        RETURN n
      CYPHER

      assert_equal expected, cypher
      assert_empty params
    end

    test 'foreach with multiple updates' do
      query = Query.new
                   .match(Cyrel.node(:n))
                   .foreach(:item, :items) do |sub|
                     sub.create(Cyrel.node(:m))
                     sub.create(Cyrel.path { node(:n) > rel(:r, :KNOWS) && rel(:r, :KNOWS) > node(:m) })
                     sub.set(Cyrel.prop(:m, :value) => :item)
                   end
                   .return_(:n)

      cypher, params = query.to_cypher

      expected = <<~CYPHER.strip
        MATCH (n)
        FOREACH (item IN $p1 | CREATE (m) CREATE (n)-[r:KNOWS]->(m) SET m.value = item)
        RETURN n
      CYPHER

      assert_equal expected, cypher
      assert_equal({ p1: :items }, params)
    end

    test 'foreach requires block' do
      assert_raises(ArgumentError, 'FOREACH requires a block with update clauses') do
        Query.new.foreach(:x, %i[a b c])
      end
    end
  end
end
