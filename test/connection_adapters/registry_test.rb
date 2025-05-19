# frozen_string_literal: true

# test/connection_adapters/registry_test.rb
require 'test_helper'

class RegistryDriverOptionsTest < ActiveSupport::TestCase
  test 'plain connection sets secure and verify_cert correctly' do
    url = 'memgraph://user:pass@localhost:7687'
    driver = ActiveCypher::ConnectionAdapters::Registry.create_driver_from_url(url)
    assert_equal false, driver.instance_variable_get(:@secure)
    assert_equal true, driver.instance_variable_get(:@verify_cert)
  end

  test 'ssl with trusted CA sets secure and verify_cert correctly' do
    url = 'memgraph+ssl://user:pass@localhost:7687'
    driver = ActiveCypher::ConnectionAdapters::Registry.create_driver_from_url(url)
    assert_equal true, driver.instance_variable_get(:@secure)
    assert_equal true, driver.instance_variable_get(:@verify_cert)
  end

  test 'ssl with self-signed cert sets secure and verify_cert correctly' do
    url = 'memgraph+ssc://user:pass@localhost:7687'
    driver = ActiveCypher::ConnectionAdapters::Registry.create_driver_from_url(url)
    assert_equal true, driver.instance_variable_get(:@secure)
    assert_equal false, driver.instance_variable_get(:@verify_cert)
  end
end
