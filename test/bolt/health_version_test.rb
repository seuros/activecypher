# frozen_string_literal: true

require 'test_helper'
require 'async'

class HealthVersionTest < ActiveSupport::TestCase
  # --- Neo4j Health and Version Tests ---

  test '[Neo4j] version detection works' do
    connection = neo4j_connection

    version_info = connection.version

    assert_not_nil version_info
    assert_equal :neo4j, version_info[:database_type]
    assert_not_nil version_info[:version]
    assert version_info[:major] >= 4, "Expected Neo4j major version >= 4, got #{version_info[:major]}"

    puts "[Neo4j] Version info: #{version_info}" if ENV['DEBUG']
  end

  test '[Neo4j] health check works' do
    connection = neo4j_connection

    health = connection.health_check

    puts "[Neo4j] Health check result: #{health.inspect}" if ENV['DEBUG']

    assert_not_nil health
    assert_equal true, health[:healthy]
    assert_not_nil health[:response_time_ms]
    assert health[:response_time_ms].positive?
    assert_includes health[:details], 'RETURN 1'

    puts "[Neo4j] Health check: #{health}" if ENV['DEBUG']
  end

  test '[Neo4j] database_info works' do
    connection = neo4j_connection

    db_info = connection.database_info

    assert_not_nil db_info
    assert_equal :neo4j, db_info[:database_type]
    assert_equal true, db_info[:healthy]
    assert_not_nil db_info[:server_agent]
    assert_not_nil db_info[:connection_id]
    assert_not_nil db_info[:protocol_version]

    puts "[Neo4j] Database info: #{db_info}" if ENV['DEBUG']
  end

  # --- Memgraph Health and Version Tests ---

  test '[Memgraph] version detection works' do
    connection = memgraph_connection

    version_info = connection.version

    puts "[Memgraph] Server agent: '#{connection.server_agent}'" if ENV['DEBUG']
    puts "[Memgraph] Version info: #{version_info}" if ENV['DEBUG']

    assert_not_nil version_info
    assert_equal :memgraph, version_info[:database_type]
    assert_not_nil version_info[:version]
    assert version_info[:major] >= 2, "Expected Memgraph major version >= 2, got #{version_info[:major]}"
  end

  test '[Memgraph] health check works' do
    connection = memgraph_connection

    health = connection.health_check

    assert_not_nil health
    assert_equal true, health[:healthy]
    assert_not_nil health[:response_time_ms]
    assert health[:response_time_ms].positive?
    assert_includes health[:details], 'SHOW STORAGE INFO'

    puts "[Memgraph] Health check: #{health}" if ENV['DEBUG']
  end

  test '[Memgraph] database_info works' do
    connection = memgraph_connection

    db_info = connection.database_info

    assert_not_nil db_info
    assert_equal :memgraph, db_info[:database_type]
    assert_equal true, db_info[:healthy]
    assert_not_nil db_info[:server_agent]
    assert_not_nil db_info[:connection_id]
    assert_not_nil db_info[:protocol_version]

    puts "[Memgraph] Database info: #{db_info}" if ENV['DEBUG']
  end
end
