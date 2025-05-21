# frozen_string_literal: true

require 'test_helper'

class InstrumentationTest < ActiveSupport::TestCase
  class TestInstrumentable
    include ActiveCypher::Instrumentation
    include ActiveCypher::Logging

    def test_instrument(payload = {})
      instrument('test', payload) { :success }
    end

    def test_query(params = {})
      instrument_query('MATCH (n) RETURN n', params) { :query_success }
    end

    def test_connection
      instrument_connection(:connect, { host: 'localhost', username: 'neo4j', password: 'secret' }) { :connected }
    end

    def test_transaction
      instrument_transaction(:commit, 123) { :committed }
    end
  end

  def setup
    @events = []
    @subscriber = ActiveSupport::Notifications.subscribe(/active_cypher/) do |name, _start, _finish, _id, payload|
      @events << { name: name, payload: payload }
    end
    @instrumentable = TestInstrumentable.new
  end

  def teardown
    ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
  end

  test 'basic instrumentation' do
    result = @instrumentable.test_instrument(test_key: 'test_value')

    assert_equal :success, result
    assert_equal 1, @events.size

    event = @events.first
    assert_equal 'active_cypher.test', event[:name]
    assert_equal 'test_value', event[:payload][:test_key]
    assert event[:payload][:duration_ms].is_a?(Numeric)
  end

  test 'query instrumentation' do
    result = @instrumentable.test_query(name: 'test')

    assert_equal :query_success, result
    assert_equal 1, @events.size

    event = @events.first
    assert_equal 'active_cypher.query', event[:name]
    assert_equal 'MATCH (n) RETURN n', event[:payload][:cypher]
    assert_equal({ name: 'test' }, event[:payload][:params])
    assert event[:payload][:duration_ms].is_a?(Numeric)
  end

  test 'connection instrumentation' do
    result = @instrumentable.test_connection

    assert_equal :connected, result
    assert_equal 1, @events.size

    event = @events.first
    assert_equal 'active_cypher.connection.connect', event[:name]
    assert_equal 'localhost', event[:payload][:config][:host]
    assert_equal 'neo4j', event[:payload][:config][:username]
    assert_equal '[FILTERED]', event[:payload][:config][:password]
    assert event[:payload][:duration_ms].is_a?(Numeric)
  end

  test 'transaction instrumentation' do
    result = @instrumentable.test_transaction

    assert_equal :committed, result
    assert_equal 1, @events.size

    event = @events.first
    assert_equal 'active_cypher.transaction.commit', event[:name]
    assert_equal 123, event[:payload][:transaction_id]
    assert event[:payload][:duration_ms].is_a?(Numeric)
  end

  test 'sensitive data is filtered' do
    config = {
      username: 'neo4j',
      password: 'supersecret',
      api_key: 'private-key',
      options: {
        token: 'auth-token',
        timeout: 30
      }
    }

    sanitized = @instrumentable.send(:sanitize_config, config)

    assert_equal 'neo4j', sanitized[:username]
    assert_equal '[FILTERED]', sanitized[:password]
    assert_equal '[FILTERED]', sanitized[:api_key]
    assert_equal 30, sanitized[:options][:timeout]
    assert_equal '[FILTERED]', sanitized[:options][:token]
  end
end
