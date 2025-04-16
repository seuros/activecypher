# frozen_string_literal: true

require 'test_helper'
class PersonNodeTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = PersonNode.new
  end
end
