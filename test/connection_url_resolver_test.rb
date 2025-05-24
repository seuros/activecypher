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

    test 'neo4j+s is treated as neo4j+ssc' do
      resolver = ConnectionUrlResolver.new('neo4j+s://user:pass@localhost:7687/mydb')
      expected = {
        adapter: 'neo4j',
        host: 'localhost',
        port: 7687,
        username: 'user',
        password: 'pass',
        database: 'mydb',
        ssl: true,
        ssc: true,
        options: {}
      }
      assert_equal expected, resolver.to_hash
      assert_equal({ secure: true, verify_cert: false }, resolver.ssl_connection_params)
    end

    test 'memgraph+s is treated as memgraph+ssc' do
      resolver = ConnectionUrlResolver.new('memgraph+s://localhost:7688')
      expected = {
        adapter: 'memgraph',
        host: 'localhost',
        port: 7688,
        username: nil,
        password: nil,
        database: 'memgraph',
        ssl: true,
        ssc: true,
        options: {}
      }
      assert_equal expected, resolver.to_hash
      assert_equal({ secure: true, verify_cert: false }, resolver.ssl_connection_params)
    end

    test '+s and +ssc produce identical results' do
      resolver_s = ConnectionUrlResolver.new('neo4j+s://user:pass@localhost:7687/db')
      resolver_ssc = ConnectionUrlResolver.new('neo4j+ssc://user:pass@localhost:7687/db')

      assert_equal resolver_ssc.to_hash, resolver_s.to_hash
      assert_equal resolver_ssc.ssl_connection_params, resolver_s.ssl_connection_params
    end
  end
end
