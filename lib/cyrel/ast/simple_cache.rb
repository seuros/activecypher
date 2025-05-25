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
        # Simple LRU: remove oldest entries when cache is full
        if @cache.size >= @max_size
          # Remove half of the oldest entries
          (@max_size / 2).times { @cache.shift }
        end
        @cache[key] = value
      end
    end
  end
end
