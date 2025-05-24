# frozen_string_literal: true

require 'test_helper'

module ActiveCypher
  module ConnectionAdapters
    class ResetIntegrationTest < ActiveSupport::TestCase
      def setup
        @adapter = connection
      end

      test 'reset! works with actual connection' do
        skip 'No database connection available' unless @adapter.active?

        # First ensure we have a working connection
        assert @adapter.active?, 'Adapter should be active'

        # Execute a query to ensure the connection is in use
        result = @adapter.execute_cypher('RETURN 1 AS num')
        assert_equal 1, result.first[:num], 'Should execute query successfully'

        # Reset should succeed
        reset_result = @adapter.reset!
        assert reset_result, "Reset should return true, but returned: #{reset_result.inspect}"

        # Connection should still be active after reset
        assert @adapter.active?, 'Connection should remain active after reset'

        # Should be able to execute queries after reset
        result = @adapter.execute_cypher('RETURN 2 AS num')
        assert_equal 2, result.first[:num], 'Should execute query after reset'
      end

      test 'reset! recovers from failed queries' do
        skip 'No database connection available' unless @adapter.active?

        # Try to execute an invalid query
        assert_raises(ActiveCypher::QueryError) do
          @adapter.execute_cypher('INVALID CYPHER QUERY')
        end

        # Reset should succeed and clear the error state
        reset_result = @adapter.reset!
        assert reset_result, "Reset should return true after error, but returned: #{reset_result.inspect}"

        # Should be able to execute valid queries after reset
        result = @adapter.execute_cypher('RETURN 3 AS num')
        assert_equal 3, result.first[:num]
      end

      test 'reset! is idempotent' do
        skip 'No database connection available' unless @adapter.active?

        # Multiple resets should all succeed
        assert @adapter.reset!
        assert @adapter.reset!
        assert @adapter.reset!

        # Connection should still work
        result = @adapter.execute_cypher('RETURN 4 AS num')
        assert_equal 4, result.first[:num]
      end

      private

      def connection
        if defined?(PersonNode) && PersonNode.respond_to?(:connection)
          PersonNode.connection
        else
          # Fallback to creating a direct connection for testing
          config = Rails.configuration.database_configuration['test']['primary']
          adapter_class = Registry.resolve(config['adapter'])
          adapter_class.new(config)
        end
      end
    end
  end
end
