# frozen_string_literal: true

require 'test_helper'
require 'async'

class ConnectionTest < ActiveSupport::TestCase
  # --- Neo4j Tests ---

  test '[Neo4j] successful connection and handshake' do
    connection = neo4j_connection

    # Verify connection state and properties
    assert connection.connected?, 'Connection should be in connected state'
    assert_equal 5.8, connection.protocol_version
    assert_match(%r{Neo4j/}, connection.server_agent)
    assert connection.connection_id, 'Connection ID should be present'
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
    connection = memgraph_connection

    assert connection.connected?
    assert_equal 5.2, connection.protocol_version # Check negotiated version
    assert_match(/Memgraph/, connection.server_agent) # Memgraph agent might vary
    assert connection.connection_id
  end
end
