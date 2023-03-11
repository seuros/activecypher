# frozen_string_literal: true

require 'helper'

# frozen_string_literal: true

require 'test_helper'

class CompanyVertexTest < ActiveSupport::TestCase
  test 'should create a company vertex' do
    company = CompanyVertex.new('Google')
    assert_equal 'Google', company.name
  end

  test 'should create a company vertex with a string representation' do
    company = CompanyVertex.new('Google')
    assert_equal 'Google', company.to_s
  end
end