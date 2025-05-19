# frozen_string_literal: true

require 'test_helper'

module ActiveCypher
  class ConnectionUrlResolverTest < ActiveSupport::TestCase
    test 'ssl_connection_params returns empty hash when no URL is given' do
      resolver = ConnectionUrlResolver.new(nil)
      assert_equal({}, resolver.ssl_connection_params)
    end

    test 'ssl_connection_params for plain connection (no SSL)' do
      resolver = ConnectionUrlResolver.new('neo4j://localhost:7687')
      assert_equal({ secure: false, verify_cert: true }, resolver.ssl_connection_params)
    end

    test 'ssl_connection_params for SSL with CA-signed certificate' do
      resolver = ConnectionUrlResolver.new('neo4j+ssl://localhost:7687')
      assert_equal({ secure: true, verify_cert: true }, resolver.ssl_connection_params)
    end

    test 'ssl_connection_params for SSL with self-signed certificate' do
      resolver = ConnectionUrlResolver.new('neo4j+ssc://localhost:7687')
      assert_equal({ secure: true, verify_cert: false }, resolver.ssl_connection_params)
    end

    test 'ssl_connection_params for connection with empty path' do
      resolver = ConnectionUrlResolver.new('memgraph+ssc://user:pass@localhost:7687/')
      assert_equal({ secure: true, verify_cert: false }, resolver.ssl_connection_params)
    end

    test 'ssl_connection_params for memgraph works the same as neo4j' do
      resolver1 = ConnectionUrlResolver.new('memgraph+ssl://localhost:7687')
      resolver2 = ConnectionUrlResolver.new('neo4j+ssl://localhost:7687')
      assert_equal(resolver1.ssl_connection_params, resolver2.ssl_connection_params)
    end
  end
end
