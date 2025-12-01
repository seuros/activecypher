# frozen_string_literal: true

# Fiber-aware storage for role/shard context.
# Async schedules many fibers on a single thread, so classic
# thread locals leak across concurrent tasks. We key values by
# Fiber object id to isolate per-task state.
require 'async/task'
module ActiveCypher
  module RuntimeRegistry
    ROLE_KEY  = :active_cypher_role
    SHARD_KEY = :active_cypher_shard

    module_function

    def current_role
      get(ROLE_KEY) || :writing
    end

    def current_role=(value)
      set(ROLE_KEY, value)
    end

    def current_shard
      get(SHARD_KEY) || :default
    end

    def current_shard=(value)
      set(SHARD_KEY, value)
    end

    # ── storage helpers ────────────────────────────────────────────

    def set(key, value)
      store = fiber_store
      store[key] = value
    end

    def get(key)
      fiber_store[key]
    end

    def fiber_store
      registry = Thread.current[:active_cypher_fiber_store] ||= {}
      registry[Fiber.current.object_id] ||= {}
    end
  end
end
