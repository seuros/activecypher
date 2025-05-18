# frozen_string_literal: true

module ActiveCypher
  class ConnectionHandler
    def initialize
      # One-level hash: db_key -> pool
      @db_key_map = {}
    end

    # Set a connection pool
    # @param db_key [Symbol] The database key (e.g., :primary, :neo4j)
    # @param pool [ConnectionPool] The connection pool
    def set(db_key, pool)
      @db_key_map[db_key.to_sym] = pool
    end

    # Get a connection pool
    # @param db_key [Symbol] The database key (e.g., :primary, :neo4j)
    # @return [ConnectionPool, nil] The connection pool, or nil if not found
    def pool(db_key)
      @db_key_map[db_key.to_sym]
    end
  end
end
