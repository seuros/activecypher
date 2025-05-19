# frozen_string_literal: true

require 'test_helper'

module ActiveCypher
  module ConnectionAdapters
    class AbstractAdapterTest < ActiveSupport::TestCase
      class SampleAdapter < AbstractAdapter
        attr_accessor :connection

        def connect
          true
        end

        def active? = true
        def execute_cypher(*) = []
      end

      # Mock for the Bolt::Connection class that just supports the inspect method
      class MockConnection
        attr_reader :host, :port, :auth_token, :secure, :verify_cert

        def initialize(host, port, adapter, auth_token:, secure:, verify_cert:, **_options)
          @host = host
          @port = port
          @adapter = adapter
          @auth_token = auth_token
          @secure = secure
          @verify_cert = verify_cert
        end

        def inspect
          filtered_auth = ActiveCypher::Redaction.filter_hash(@auth_token)
          "#<#{self.class.name}:0x#{object_id.to_s(16)} @host=#{@host.inspect}, @port=#{@port.inspect}, " \
            "@auth_token=#{filtered_auth.inspect}, @secure=#{@secure.inspect}, @verify_cert=#{@verify_cert.inspect}>"
        end
      end

      test 'inspect method redacts sensitive information in adapter' do
        config = {
          adapter: 'sample',
          host: 'localhost',
          port: 7687,
          username: 'user',
          password: 'secret_password',
          database: 'graph',
          ssl: true,
          ssc: true,
          url: 'sample+ssc://user:secret_password@localhost:7687',
          auth_token: { scheme: 'basic', principal: 'user', credentials: 'secret_password' },
          options: { timeout: 30 }
        }

        adapter = SampleAdapter.new(config)
        inspect_output = adapter.inspect

        # Check that sensitive data is redacted
        assert_includes inspect_output, ActiveCypher::Redaction::MASK
        assert_not_includes inspect_output, 'secret_password'

        # Check that non-sensitive data is still included
        assert_includes inspect_output, 'localhost'
        assert_includes inspect_output, '7687'
        assert_includes inspect_output, 'sample'
        assert_includes inspect_output, 'true'

        # Check format of the inspect output
        assert_match(/#<ActiveCypher::ConnectionAdapters::AbstractAdapterTest::SampleAdapter:0x[a-f0-9]+ @config=/, inspect_output)
      end

      test 'inspect method redacts sensitive information in connection' do
        # Use our mock instead of the real connection to avoid dependencies
        connection = MockConnection.new(
          'localhost', 7687, nil,
          auth_token: { scheme: 'basic', principal: 'test_user', credentials: 'test_password' },
          secure: true,
          verify_cert: false
        )

        connection_output = connection.inspect

        # Check that sensitive data is redacted
        assert_includes connection_output, ActiveCypher::Redaction::MASK
        assert_not_includes connection_output, 'test_password'
        assert_not_includes connection_output, 'test_user'

        # Check that non-sensitive data is still included
        assert_includes connection_output, 'localhost'
        assert_includes connection_output, '7687'
        assert_includes connection_output, 'secure=true'

        # Check format of the inspect output
        assert_match(/#<ActiveCypher::ConnectionAdapters::AbstractAdapterTest::MockConnection:0x[a-f0-9]+/, connection_output)
      end
    end
  end
end
