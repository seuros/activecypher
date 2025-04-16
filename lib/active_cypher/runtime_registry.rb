# frozen_string_literal: true

module ActiveCypher
  module RuntimeRegistry
    thread_mattr_accessor :current_role, default: :writing
    thread_mattr_accessor :current_shard, default: :default
  end
end
