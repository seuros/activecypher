# frozen_string_literal: true

require 'test_helper'

class MigrationDSLTest < ActiveSupport::TestCase
  class CaptureAdapter < ActiveCypher::ConnectionAdapters::AbstractAdapter
    attr_reader :executed

    def initialize
      @executed = []
    end

    def vendor = :neo4j

    def execute_cypher(cypher, _params = {}, _ctx = 'Query')
      @executed << cypher.strip
      []
    end
  end

  test 'DSL methods generate expected cypher' do
    klass = Class.new(ActiveCypher::Migration) do
      up do
        create_node_index :Foo, :bar, name: :foo_bar_idx
        create_rel_index :BARREL, :kind
        create_uniqueness_constraint :Foo, :bar, name: :foo_bar_unique
        execute 'CREATE INDEX IF NOT EXISTS FOR (f:Foo) ON (f.created_at)'
      end
    end

    adapter = CaptureAdapter.new
    klass.new(adapter).run

    assert_equal [
      'CREATE INDEX foo_bar_idx IF NOT EXISTS FOR (n:Foo) ON (n.bar)',
      'CREATE INDEX IF NOT EXISTS FOR ()-[r:BARREL]-() ON (r.kind)',
      'CREATE CONSTRAINT foo_bar_unique IF NOT EXISTS FOR (n:Foo) REQUIRE (n.bar) IS UNIQUE',
      'CREATE INDEX IF NOT EXISTS FOR (f:Foo) ON (f.created_at)'
    ], adapter.executed
  end
end
