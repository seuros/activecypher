# frozen_string_literal: true

require 'singleton'

module Cyrel
  module AST
    # Simple thread-safe compilation cache
    # Because compiling the same query twice is like watching reruns
    class SimpleCache
      include Singleton

      def initialize
        @cache = {}
        @mutex = Mutex.new
        @max_size = 1000
      end

      def fetch(key)
        @mutex.synchronize do
          if @cache.key?(key)
            @cache[key]
          elsif block_given?
            value = yield
            store(key, value)
            value
          end
        end
      end

      def clear!
        @mutex.synchronize { @cache.clear }
      end

      def size
        @mutex.synchronize { @cache.size }
      end

      private

      def store(key, value)
        # Simple LRU: clear half the cache when it gets too big
        if @cache.size >= @max_size
          @cache.shift(@max_size / 2)
        end
        @cache[key] = value
      end
    end
  end
end