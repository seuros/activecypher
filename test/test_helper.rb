# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'
require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

require_relative 'dummy/config/environment'

# Require Minitest autorun to execute the tests
require 'minitest/autorun'

PropCheck::Property.configure do |c|
  c.n_runs = ENV.fetch('PROP_CHECK_RUNS', 50).to_i
end

G = PropCheck::Generators

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors) if ENV['PARALLEL_TESTS']&.to_i&.positive?
  end
end

# Boot a singleton Bolt driver for the whole suite
module ActiveCypherTest
  class DriverHarness
    def self.driver
      neo4j_adapter = ActiveCypher::ConnectionAdapters::Neo4jAdapter.new({
                                                                           uri: ENV.fetch('BOLT_URI', 'bolt://localhost:7687'),
                                                                           username: ENV.fetch('BOLT_USER', 'neo4j'),
                                                                           password: ENV.fetch('BOLT_PASS', 'activecypher')
                                                                         })
      @driver ||= ActiveCypher::Bolt::Driver.new(
        uri: ENV.fetch('BOLT_URI', 'bolt://localhost:7687'),
        adapter: neo4j_adapter,
        auth_token: { scheme: 'basic',
                      principal: ENV.fetch('BOLT_USER', 'neo4j'),
                      credentials: ENV.fetch('BOLT_PASS', 'activecypher') },
        pool_size: 5
      )
    end
  end
end

Minitest.after_run { ActiveCypherTest::DriverHarness.driver.close }

module DuplicateTestWarning
  ObjectSpace.each_object(Class).select { |c| c < Minitest::Test }
             .group_by(&:name).each do |name, klasses|
    warn "⚠️  Duplicate test class #{name}" if klasses.size > 1
  end
end

module ActiveCypherTest
  module PersistedHelper
    def persisted(klass, attrs = {}, id:)
      klass.new(attrs).tap do |o|
        o.internal_id = id.to_s
        o.instance_variable_set(:@new_record, false)
      end
    end
  end
end

ActiveSupport::TestCase.include ActiveCypherTest::PersistedHelper

class StubConnection
  attr_reader :last_cypher, :last_params, :last_ctx, :last_internal_id

  class_attribute :last_internal_id

  def initialize(rid = 'RID‑123')
    @rid = rid
    self.class.last_internal_id = rid
  end

  def execute_cypher(cypher, params = {}, ctx = 'Query')
    @last_cypher = cypher
    @last_params = params
    @last_ctx = ctx
    [{ rid: @rid }]
  end
end
