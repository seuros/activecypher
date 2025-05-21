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
end

ActiveCypher::ConnectionAdapters::Registry.register('dummy', DummyAdapter)
