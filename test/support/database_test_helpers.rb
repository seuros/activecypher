# frozen_string_literal: true

module DatabaseTestHelpers
  # Configuration constants for backward compatibility with error condition tests
  NEO4J_CONFIG = { host: '127.0.0.1', port: 17687,
                   auth_token: { scheme: 'basic', principal: 'neo4j', credentials: 'activecypher' } }.freeze
  MEMGRAPH_CONFIG = { host: '127.0.0.1', port: 17688, auth_token: { scheme: 'basic', principal: 'memgraph',
                                                                   credentials: 'activecypher' } }.freeze

  # Gets the Neo4j connection from the abstract Neo4jRecord class
  def neo4j_connection
    Neo4jRecord.connection.raw_connection
  rescue ActiveCypher::ConnectionError => e
    skip "Neo4j connection failed: #{e.message}"
  end

  # Gets the Memgraph connection from the abstract MemgraphRecord class
  def memgraph_connection
    MemgraphRecord.connection.raw_connection
  rescue ActiveCypher::ConnectionError => e
    skip "Memgraph connection failed: #{e.message}"
  end

  # Helper method for creating test adapters (for error condition tests)
  def create_adapter(host, port, username, password)
    ActiveCypher::ConnectionAdapters::Neo4jAdapter.new({
                                                         uri: "bolt://#{host}:#{port}",
                                                         username: username,
                                                         password: password
                                                       })
  end

  # Helper to safely close connections
  def safe_close(connection)
    return unless connection

    connection.close if connection.connected?
  rescue StandardError => e
    puts "Error closing connection: #{e.message}" if ENV['DEBUG']
  end

  # Helper to check if a connection is available (for skipping tests)
  def connection_available?(connection)
    connection.connect
    true
  rescue StandardError => e
    puts "Connection not available: #{e.message}" if ENV['DEBUG']
    false
  end
end
