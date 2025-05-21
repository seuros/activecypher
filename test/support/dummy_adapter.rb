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
end
