# frozen_string_literal: true

module ActiveCypher
  class ConnectionHandler
    def initialize = @role_shard_map = Hash.new { |h, k| h[k] = {} }
    def set(role, shard, pool) = (@role_shard_map[role][shard] = pool)
    def pool(role, shard)      = @role_shard_map.dig(role, shard)
  end
end
