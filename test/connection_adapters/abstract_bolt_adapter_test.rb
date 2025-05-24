# frozen_string_literal: true

require 'test_helper'
require 'logger'

module ActiveCypher
  module ConnectionAdapters
    class AbstractBoltAdapterTest < ActiveSupport::TestCase
      # Create a concrete implementation for testing
      class TestBoltAdapter < AbstractBoltAdapter
        def protocol_handler_class
          TestProtocolHandler
        end

        def validate_connection
          true
        end

        def execute_cypher(_query, _params = {}, _context = 'Query')
          []
        end
      end

      class TestProtocolHandler < AbstractProtocolHandler
        def extract_version(_agent)
          'test/1.0'
        end
      end

      # Mock Bolt::Connection for testing
      class MockBoltConnection
        attr_reader :reset_called, :connected, :adapter
        attr_accessor :messages_written, :responses

        def initialize(adapter = nil)
          @reset_called = false
          @connected = true
          @adapter = adapter
          @messages_written = []
          @responses = []
        end

        def connected?
          @connected
        end

        def reset!
          @reset_called = true
          true
        end

        def disconnect!
          @connected = false
        end

        def write_message(message)
          @messages_written << message
        end

        def read_message
          @responses.shift || ActiveCypher::Bolt::Messaging::Success.new({})
        end
      end

      def setup
        @config = {
          adapter: 'test_bolt',
          host: 'localhost',
          port: 7687,
          username: 'test',
          password: 'test',
          database: 'test'
        }
        @adapter = TestBoltAdapter.new(@config)
      end

      test 'reset! returns false when not connected' do
        # Adapter starts without a connection
        assert_equal false, @adapter.reset!
      end

      test 'reset! calls connection reset when connected' do
        # Set up a mock connection
        mock_connection = MockBoltConnection.new(@adapter)
        @adapter.instance_variable_set(:@connection, mock_connection)

        # Verify the adapter is active
        assert @adapter.active?

        # Call reset!
        result = @adapter.reset!

        # Verify reset succeeded
        assert_equal true, result
      end

      test 'reset! returns false and logs error when connection reset fails' do
        # Mock connection that raises an error on write_message
        mock_connection = MockBoltConnection.new(@adapter)
        mock_connection.define_singleton_method(:write_message) do |_msg|
          raise StandardError, 'Connection error during reset'
        end
        @adapter.instance_variable_set(:@connection, mock_connection)

        # Capture logs
        log_output = StringIO.new
        test_logger = Logger.new(log_output)
        test_logger.level = Logger::DEBUG
        # Mock the logger method using instance_eval to access private method
        @adapter.instance_eval do
          define_singleton_method(:logger) { test_logger }
        end

        # Call reset!
        result = @adapter.reset!

        # Verify it returns false
        assert_equal false, result

        # Verify error was logged
        log_output.rewind
        log_contents = log_output.read
        assert_includes log_contents, 'Reset failed'
      end

      test 'reset! is instrumented' do
        # Set up a mock connection
        mock_connection = MockBoltConnection.new(@adapter)
        @adapter.instance_variable_set(:@connection, mock_connection)

        # Track instrumentation events
        events = []
        subscriber = ActiveSupport::Notifications.subscribe('active_cypher.connection.reset') do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          events << event
        end

        # Call reset!
        @adapter.reset!

        # Verify instrumentation event was sent
        assert_equal 1, events.size
        event = events.first
        assert_equal 'active_cypher.connection.reset', event.name
        assert event.payload.key?(:duration_ms)
        assert event.duration >= 0

        # Cleanup
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      test 'reset! handles connection errors gracefully' do
        # Mock connection that raises a connection error
        mock_connection = MockBoltConnection.new(@adapter)
        mock_connection.define_singleton_method(:read_message) do
          raise ActiveCypher::Bolt::ConnectionError, 'Connection lost'
        end
        @adapter.instance_variable_set(:@connection, mock_connection)

        # Call reset! should not raise, but return false
        assert_nothing_raised do
          result = @adapter.reset!
          assert_equal false, result
        end
      end
    end
  end
end
