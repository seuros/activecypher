# frozen_string_literal: true

require 'test_helper'

class CompanyNodeValidationTest < ActiveSupport::TestCase
  def test_company_node_requires_name
    company = CompanyNode.create
    refute company.persisted?, 'CompanyNode should not be persisted without a name'
    assert_includes company.errors[:name], "can't be blank"
  end

  def test_company_node_with_name_is_persisted
    company = CompanyNode.create(name: 'Acme Corp')
    assert company.persisted?, 'CompanyNode with a name should be persisted'
    assert_empty company.errors[:name]
  end
end
