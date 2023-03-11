# frozen_string_literal: true

gem 'redis-client'

module ActiveCypher
  module Databases
    class RedisGraph < BaseDatabase
      def initialize
        @connection = RedisClient.new
      end
    end
  end
end
