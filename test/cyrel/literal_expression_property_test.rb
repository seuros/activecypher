# frozen_string_literal: true

require 'test_helper'
require_relative 'support/generators'

class LiteralExpressionPropertyTest < ActiveSupport::TestCase
  include TestGenerators

  test 'Expression::Literal round‑trips through #parameters' do
    PropCheck.forall value: Literal do |value|
      q     = Cyrel::Query.new
      expr  = Cyrel::Expression::Literal.new(value)
      token = expr.render(q)

      if value.nil?
        assert_equal 'NULL', token
        assert_empty q.parameters
      else
        assert_match(/\A\$p\d+\z/, token) # placeholder shape
        assert_includes q.parameters.values, value
      end
    end
  end
end
