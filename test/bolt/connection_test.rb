# frozen_string_literal: true

require 'test_helper'
require 'async'

class ConnectionTest < ActiveSupport::TestCase
  # NOTE: Assumes Docker containers (neo4j, memgraph) from docker-compose.yml are running
  # Or GHA CI is running the tests with the containers
  NEO4J_CONFIG = { host: '127.0.0.1', port: 7687,
                   auth_token: { scheme: 'basic', principal: 'neo4j', credentials: 'activecypher' } }.freeze
  MEMGRAPH_CONFIG = { host: '127.0.0.1', port: 7688, auth_token: { scheme: 'basic', principal: 'memgraph',
                                                                   credentials: 'activecypher' } }.freeze

  def create_adapter(host, port, username, password)
    ActiveCypher::ConnectionAdapters::Neo4jAdapter.new({
                                                         uri: "bolt://#{host}:#{port}",
                                                         username: username,
                                                         password: password
                                                       })
  end

  def safe_close(connection)
    return unless connection

    connection.close if connection.respond_to?(:close) && connection.connected?
  rescue StandardError => e
    puts "Error closing connection: #{e.message}" if ENV['DEBUG']
  end

  # --- Neo4j Tests ---

  test '[Neo4j] successful connection and handshake' do
    adapter = create_adapter(
      NEO4J_CONFIG[:host],
      NEO4J_CONFIG[:port],
      NEO4J_CONFIG[:auth_token][:principal],
      NEO4J_CONFIG[:auth_token][:credentials]
    )

    connection = nil
    begin
      connection = ActiveCypher::Bolt::Connection.new(
        NEO4J_CONFIG[:host],
        NEO4J_CONFIG[:port],
        adapter,
        auth_token: NEO4J_CONFIG[:auth_token],
        timeout_seconds: 5
      )

      # This should not raise an exception
      Sync { connection.connect }

      # Verify connection state and properties
      assert connection.connected?, 'Connection should be in connected state'
      assert_equal 5.8, connection.protocol_version
      assert_match(%r{Neo4j/}, connection.server_agent)
      assert connection.connection_id, 'Connection ID should be present'
    ensure
      safe_close(connection)
    end
  end

  test '[Neo4j] connection fails with bad port' do
    bad_port = NEO4J_CONFIG[:port] + 20
    adapter = create_adapter(
      NEO4J_CONFIG[:host],
      bad_port,
      NEO4J_CONFIG[:auth_token][:principal],
      NEO4J_CONFIG[:auth_token][:credentials]
    )

    connection = nil
    begin
      # Create the connection outside Sync block
      connection = ActiveCypher::Bolt::Connection.new(
        NEO4J_CONFIG[:host],
        bad_port,
        adapter,
        auth_token: NEO4J_CONFIG[:auth_token],
        timeout_seconds: 2
      )

      # Completely avoid using Sync here - the test should raise
      # a ConnectionError without the need for an async block
      error = assert_raises(ActiveCypher::ConnectionError) do
        connection.connect
      end

      assert_match(/Failed to connect|Connection refused|timed out/i, error.message)
      refute connection.connected?, 'Connection should not be in connected state'
    ensure
      safe_close(connection)
    end
  end

  test '[Neo4j] authentication fails with bad password' do
    bad_auth = NEO4J_CONFIG[:auth_token].merge(credentials: 'wrongpassword')
    adapter = create_adapter(
      NEO4J_CONFIG[:host],
      NEO4J_CONFIG[:port],
      bad_auth[:principal],
      bad_auth[:credentials]
    )

    connection = nil
    begin
      connection = ActiveCypher::Bolt::Connection.new(
        NEO4J_CONFIG[:host],
        NEO4J_CONFIG[:port],
        adapter,
        auth_token: bad_auth,
        timeout_seconds: 5
      )

      # Test should raise a ConnectionError directly
      error = assert_raises(ActiveCypher::ConnectionError) do
        connection.connect
      end

      assert_match(/Authentication failed|unauthorized/i, error.message)
      refute connection.connected?, 'Connection should not be in connected state'
    ensure
      safe_close(connection)
    end
  end

  test '[Neo4j] connection can reconnect after disconnection' do
    adapter = create_adapter(
      NEO4J_CONFIG[:host],
      NEO4J_CONFIG[:port],
      NEO4J_CONFIG[:auth_token][:principal],
      NEO4J_CONFIG[:auth_token][:credentials]
    )

    connection = nil
    begin
      connection = ActiveCypher::Bolt::Connection.new(
        NEO4J_CONFIG[:host],
        NEO4J_CONFIG[:port],
        adapter,
        auth_token: NEO4J_CONFIG[:auth_token],
        timeout_seconds: 5
      )

      # Initial connection
      Sync { connection.connect }
      assert connection.connected?, 'Connection should be in connected state'

      # Close the connection
      connection.close
      refute connection.connected?, 'Connection should be closed'

      # Reconnect
      Sync { assert connection.reconnect, 'Reconnection should succeed' }
      assert connection.connected?, 'Connection should be reconnected'
    ensure
      safe_close(connection)
    end
  end

  # --- Memgraph Tests ---

  test '[Memgraph] successful connection and handshake' do
    skip 'Skipping Memgraph test (may not be available)' unless ENV['TEST_MEMGRAPH']

    connection = nil
    begin
      adapter = ActiveCypher::ConnectionAdapters::MemgraphAdapter.new({
                                                                        uri: "bolt://#{MEMGRAPH_CONFIG[:host]}:#{MEMGRAPH_CONFIG[:port]}",
                                                                        username: MEMGRAPH_CONFIG[:auth_token][:principal],
                                                                        password: MEMGRAPH_CONFIG[:auth_token][:credentials]
                                                                      })

      connection = ActiveCypher::Bolt::Connection.new(
        MEMGRAPH_CONFIG[:host],
        MEMGRAPH_CONFIG[:port],
        adapter,
        auth_token: MEMGRAPH_CONFIG[:auth_token],
        timeout_seconds: 5
      )

      Sync { connection.connect }
      assert connection.connected?
      assert_equal 5.2, connection.protocol_version # Check negotiated version
      assert_match(/Memgraph/, connection.server_agent) # Memgraph agent might vary
      assert connection.connection_id
    ensure
      safe_close(connection)
    end
  end
end
