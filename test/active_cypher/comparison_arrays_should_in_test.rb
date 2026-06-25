# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

module Cyrel
  class ComparisonArraysShouldIn < ActiveSupport::TestCase    
    test 'where with eq string should = string' do
      alice = PersonNode.create(name: 'Alice')
      bob = PersonNode.create(name: 'Bob')
      charlie = PersonNode.create(name: 'Charlie')
      cypher_string, params_hash = PersonNode.where(name: 'Alice').cyrel_query.to_cypher
      expected_cypher = <<~CYPHER.chomp.strip
        MATCH (n:Person)
        WHERE (n.name = $p1)
        RETURN n, __NODE_ID__(n) AS internal_id
      CYPHER
      expected_params = { p1: 'Alice' }
      assert_equal [expected_cypher, expected_params], [cypher_string, params_hash]
    end

    test 'where with eq array should IN array' do
      alice = PersonNode.create(name: 'Alice')
      bob = PersonNode.create(name: 'Bob')
      charlie = PersonNode.create(name: 'Charlie')
      cypher_string, params_hash = PersonNode.where(name: ['Alice', 'Bob']).cyrel_query.to_cypher
      expected_cypher = <<~CYPHER.chomp.strip
        MATCH (n:Person)
        WHERE (n.name IN $p1)
        RETURN n, __NODE_ID__(n) AS internal_id
      CYPHER
      expected_params = { p1: ['Alice', 'Bob'] }
      assert_equal [expected_cypher, expected_params], [cypher_string, params_hash]
    end
  end
end
