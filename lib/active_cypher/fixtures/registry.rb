# frozen_string_literal: true

module ActiveCypher
  module Fixtures
    # Singleton registry for logical ref => model instance mapping
    class Registry
      @store = {}

      class << self
        # Store loaded instance
        # @param ref [Symbol, String]
        # @param obj [Object]
        def add(ref, obj)
          raise ArgumentError, "Duplicate fixture ref: #{ref.inspect}" if @store.key?(ref.to_sym)

          @store[ref.to_sym] = obj
        end

        # Fetch in tests (`[]` delegate)
        # @param ref [Symbol, String]
        # @return [Object, nil]
        def get(ref)
          @store[ref.to_sym]
        end

        # Purge registry between loads
        def reset!
          @store.clear
        end

        # Allow bracket access: Registry[:foo]
        def [](ref)
          get(ref)
        end

        # For debugging or introspection
        def all
          @store.dup
        end
      end
    end
  end
end
