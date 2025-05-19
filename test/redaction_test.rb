# frozen_string_literal: true

require 'test_helper'

module ActiveCypher
  class RedactionTest < ActiveSupport::TestCase
    test 'filter_hash redacts sensitive keys' do
      input = {
        username: 'user',
        password: 'secret_password',
        credentials: 'secret_token',
        auth_token: { scheme: 'basic', principal: 'user', credentials: 'password' },
        url: 'memgraph+ssc://user:password@localhost:7687',
        safe_param: 'visible_value'
      }

      filtered = Redaction.filter_hash(input)

      # Check sensitive data is masked
      assert_equal Redaction::MASK, filtered[:password]
      assert_equal Redaction::MASK, filtered[:credentials]
      assert_equal Redaction::MASK, filtered[:url]

      # Check the entire auth_token was masked since it contains sensitive fields
      assert_equal Redaction::MASK, filtered[:auth_token]

      # Check safe values remain unchanged
      assert_equal 'user', filtered[:username]
      assert_equal 'visible_value', filtered[:safe_param]
    end

    test 'create_filter works with additional keys' do
      input = {
        username: 'visible',
        api_key: 'hidden',
        normal_param: 'visible'
      }

      # Filter with additional key
      filter = Redaction.create_filter([:api_key])
      filtered = filter.filter(input)

      assert_equal 'visible', filtered[:username]
      assert_equal 'visible', filtered[:normal_param]
      assert_equal Redaction::MASK, filtered[:api_key]
    end

    test 'MASK constant is set to [HUNTER2]' do
      assert_equal '[HUNTER2]', Redaction::MASK
    end
  end
end
