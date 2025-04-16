# frozen_string_literal: true

require 'test_helper'

module ActiveCypher
  class ConnectionUrlResolverTest < ActiveSupport::TestCase
    def setup
      # Nothing to set up
    end

    def test_neo4j_minimal_url
      resolver = ConnectionUrlResolver.new('neo4j://localhost')
      config = resolver.to_hash

      assert_equal 'neo4j', config[:adapter]
      assert_equal 'localhost', config[:host]
      assert_equal 7687, config[:port]
      assert_nil config[:username]
      assert_nil config[:password]
      assert_equal false, config[:ssl]
      assert_equal false, config[:ssc]
      assert_equal({}, config[:options])
    end

    def test_memgraph_with_auth
      resolver = ConnectionUrlResolver.new('memgraph://user:pass@localhost:7687')
      config = resolver.to_hash

      assert_equal 'memgraph', config[:adapter]
      assert_equal 'localhost', config[:host]
      assert_equal 7687, config[:port]
      assert_equal 'user', config[:username]
      assert_equal 'pass', config[:password]
      assert_equal false, config[:ssl]
      assert_equal false, config[:ssc]
    end

    def test_neo4j_with_ssl
      resolver = ConnectionUrlResolver.new('neo4j+ssl://localhost')
      config = resolver.to_hash

      assert_equal 'neo4j', config[:adapter]
      assert_equal 'localhost', config[:host]
      assert_equal 7687, config[:port]
      assert_nil config[:username]
      assert_nil config[:password]
      assert_equal true, config[:ssl]
      assert_equal false, config[:ssc]
    end

    def test_memgraph_with_ssl
      resolver = ConnectionUrlResolver.new('memgraph+ssl://localhost')
      config = resolver.to_hash

      assert_equal 'memgraph', config[:adapter]
      assert_equal true, config[:ssl]
      assert_equal false, config[:ssc]
    end

    def test_neo4j_with_self_signed_certs
      resolver = ConnectionUrlResolver.new('neo4j+ssc://localhost')
      config = resolver.to_hash

      assert_equal 'neo4j', config[:adapter]
      assert_equal true, config[:ssl]
      assert_equal true, config[:ssc]
    end

    def test_memgraph_with_self_signed_certs
      resolver = ConnectionUrlResolver.new('memgraph+ssc://localhost')
      config = resolver.to_hash

      assert_equal 'memgraph', config[:adapter]
      assert_equal true, config[:ssl]
      assert_equal true, config[:ssc]
    end

    def test_with_both_ssl_and_ssc
      resolver = ConnectionUrlResolver.new('neo4j+ssl+ssc://localhost')
      config = resolver.to_hash

      assert_equal 'neo4j', config[:adapter]
      assert_equal true, config[:ssl]
      assert_equal true, config[:ssc]
    end

    def test_with_username_password
      resolver = ConnectionUrlResolver.new('memgraph://admin:secret@127.0.0.1:7687')
      config = resolver.to_hash

      assert_equal 'memgraph', config[:adapter]
      assert_equal '127.0.0.1', config[:host]
      assert_equal 7687, config[:port]
      assert_equal 'admin', config[:username]
      assert_equal 'secret', config[:password]
    end

    def test_with_complex_password
      resolver = ConnectionUrlResolver.new('neo4j://user:p%40ssw0rd%21@localhost:7687')
      config = resolver.to_hash

      assert_equal 'neo4j', config[:adapter]
      assert_equal 'user', config[:username]
      assert_equal 'p@ssw0rd!', config[:password]
    end

    def test_with_query_params
      resolver = ConnectionUrlResolver.new('neo4j://localhost:7687?timeout=10&pool=5')
      config = resolver.to_hash

      assert_equal 'neo4j', config[:adapter]
      assert_equal({ timeout: '10', pool: '5' }, config[:options])
    end

    def test_with_database_path
      resolver = ConnectionUrlResolver.new('neo4j://localhost:7687/mydb')
      config = resolver.to_hash

      assert_equal 'neo4j', config[:adapter]
      assert_equal 'mydb', config[:database]
    end

    def test_default_port_when_not_specified
      resolver = ConnectionUrlResolver.new('neo4j://localhost')
      config = resolver.to_hash

      assert_equal 7687, config[:port]
    end

    def test_invalid_scheme
      resolver = ConnectionUrlResolver.new('invalid://localhost')
      assert_nil resolver.to_hash
    end

    def test_invalid_url_format
      resolver = ConnectionUrlResolver.new('memgraph:/missing/slashes')
      assert_nil resolver.to_hash
    end

    def test_unknown_modifier
      resolver = ConnectionUrlResolver.new('neo4j+foo://badoption')
      assert_nil resolver.to_hash
    end

    def test_nil_url
      resolver = ConnectionUrlResolver.new(nil)
      assert_nil resolver.to_hash
    end

    def test_empty_url
      resolver = ConnectionUrlResolver.new('')
      assert_nil resolver.to_hash
    end
  end
end
