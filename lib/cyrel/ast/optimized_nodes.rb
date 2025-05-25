# frozen_string_literal: true

module Cyrel
  module AST
    # Optimized nodes using Data for frequently used, simple nodes
    # These benefit from Data's automatic hash/== and immutability

    # For simple value nodes, Data is perfect
    module OptimizedNodes
      # Literal values - these are created frequently and benefit from Data
      LiteralData = Data.define(:value) do
        def accept(visitor)
          visitor.visit_literal_data(self)
        end
      end

      # Simple expression nodes that benefit from fast equality
      PropertyAccessData = Data.define(:variable, :property_name) do
        def accept(visitor)
          visitor.visit_property_access_data(self)
        end
      end

      # Skip and Limit are perfect for Data - simple, immutable
      SkipData = Data.define(:expression) do
        def accept(visitor)
          visitor.visit_skip_data(self)
        end
      end

      LimitData = Data.define(:expression) do
        def accept(visitor)
          visitor.visit_limit_data(self)
        end
      end
    end

    # Optimized cache that takes advantage of Data's hash/==
    class OptimizedCache
      include Singleton

      def initialize
        @cache = {}
        @max_size = 1000
        @mutex = Mutex.new
      end

      def fetch(node)
        # Data objects have reliable hash/== so we can use them directly as keys
        @mutex.synchronize do
          if @cache.key?(node)
            @cache[node]
          else
            value = yield
            store(node, value)
            value
          end
        end
      end

      private

      def store(node, value)
        if @cache.size >= @max_size
          # LRU eviction
          @cache.shift
        end
        @cache[node] = value
      end
    end

    # Example of how to use Data nodes effectively
    class HybridApproach
      # Use Data for simple, frequently created nodes
      # Use Classes for complex nodes with behavior

      def self.create_literal(value)
        # Literals are perfect for Data - immutable, simple
        OptimizedNodes::LiteralData.new(value)
      end

      def self.create_match(pattern, optional: false)
        # Complex nodes with optional parameters stay as classes
        MatchNode.new(pattern, optional: optional)
      end

      def self.benchmark_hybrid
        require 'benchmark'

        n = 10_000
        puts "\nHybrid Approach Benchmark:"
        puts '-' * 40

        Benchmark.bm(35) do |x|
          x.report('Create literals (Class)') do
            n.times { |i| LiteralNode.new(i) }
          end

          x.report('Create literals (Data)') do
            n.times { |i| OptimizedNodes::LiteralData.new(i) }
          end

          # Cache performance with Data nodes
          cache = OptimizedCache.instance
          literals = 100.times.map { |i| OptimizedNodes::LiteralData.new(i) }

          x.report('Cache lookups (Data as key)') do
            n.times do |i|
              node = literals[i % 100]
              cache.fetch(node) { "value_#{i}" }
            end
          end
        end
      end
    end
  end
end
