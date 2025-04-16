# frozen_string_literal: true

require 'test_helper'

class TestActiveCypher < ActiveSupport::TestCase
  def test_that_it_has_a_version_number
    refute_nil Gem::Specification.find_by_name('activevector').version
  end
end
