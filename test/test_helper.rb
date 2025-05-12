# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'
require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

require_relative 'dummy/config/environment'

PropCheck::Property.configure do |c|
  c.n_runs = ENV.fetch('PROP_CHECK_RUNS', 50).to_i
end

G = PropCheck::Generators

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
