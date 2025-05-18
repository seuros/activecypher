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

  def test_company_node_update_name_validation
    company = CompanyNode.create(name: 'Initial Name')
    assert company.persisted?, 'CompanyNode should be created with a name'

    company.name = ''
    refute company.save, 'CompanyNode should not be saved with a blank name'
    assert_includes company.errors[:name], "can't be blank"

    company.name = 'Updated Name'
    assert company.save, 'CompanyNode should be saved with a valid name'
    assert_empty company.errors[:name]
  end
end
