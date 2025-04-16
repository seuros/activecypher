# frozen_string_literal: true

require 'test_helper'

class ParameterPropertiesTest < ActiveSupport::TestCase
  test 'register_parameter always yields unique keys' do
    PropCheck.forall values: G.array(G.one_of(G.integer, G.string)) do |values|
      q = Cyrel::Query.new
      values.each { |v| q.register_parameter(v) }

      assert_equal q.parameters.keys.uniq.size, q.parameters.keys.size
    end
  end
end
