# frozen_string_literal: true

require 'test_helper'

class GemVersionTest < ActiveSupport::TestCase
  test 'returns a Gem::Version instance' do
    version = ActiveCypher.gem_version
    assert_kind_of Gem::Version, version
  end

  test 'matches the VERSION constant' do
    version = ActiveCypher.gem_version
    assert_equal ActiveCypher::VERSION, version.to_s
  end
end
