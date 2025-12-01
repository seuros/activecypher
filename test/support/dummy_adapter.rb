# frozen_string_literal: true

class DummyAdapter < ActiveCypher::ConnectionAdapters::AbstractAdapter
  attr_reader :executed

  def initialize(config = {})
    super
    @executed = []
    @versions = []
    @connected = false
  end

  def connect
    @connected = true
  end

  def active?
    @connected
  end

  def execute_cypher(cypher, _params = {}, _ctx = 'Query')
    @executed << cypher.strip
    if cypher.start_with?('MATCH (m:SchemaMigration)')
      @versions.map { |v| { version: v } }
    elsif cypher.start_with?('CREATE (:SchemaMigration')
      version = cypher.match(/version:\s*['"]?(\d+)/)[1]
      @versions << version
      []
    else
      []
    end
  end

  ID_FUNCTION = 'id'

  def vendor = :memgraph

  def ensure_schema_migration_constraint
    @executed << 'CREATE CONSTRAINT graph_schema_migration'
  end

  def execute_ddl(cypher, params = {})
    execute_cypher(cypher, params)
  end

  # Return self as id_handler for compatibility with relationship tests
  def id_handler
    self.class
  end

  def schema_catalog
    idx = ActiveCypher::Schema::IndexDef.new('test_index', :node, 'Test', ['name'], false, nil)
    con = ActiveCypher::Schema::ConstraintDef.new('uniq_test', 'Test', ['name'], :unique)
    node = ActiveCypher::Schema::NodeTypeDef.new('Test', ['name'], nil)
    ActiveCypher::Schema::Catalog.new(indexes: [idx], constraints: [con], node_types: [node], edge_types: [])
  end

  module Persistence
    module_function

    def create_record(model)
      model.internal_id = (model.internal_id || 0) + 1
      model.instance_variable_set(:@new_record, false)
      model.send(:changes_applied)
      true
    end

    def update_record(model)
      model.send(:changes_applied)
      true
    end

    def destroy_record(_model)
      true
    end
  end
end

ActiveCypher::ConnectionAdapters::Registry.register('dummy', DummyAdapter)
