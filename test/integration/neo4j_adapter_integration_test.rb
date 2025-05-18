# frozen_string_literal: true

require 'test_helper'

class Neo4jAdapterIntegrationTest < ActiveSupport::TestCase
  def setup
    connection.execute_cypher('MATCH (n) DETACH DELETE n')

    assert_changes -> { connection.execute_cypher('MATCH (n) RETURN count(n) AS count', {})[0][:count].to_i }, 2 do
      CompanyNode.create(name: 'Acme Corp', founding_year: 1990, active: true)
      CompanyNode.create(name: 'Globex Inc', founding_year: 1980, active: false)
    end
  end

  def test_find_fetches_correct_node
    # Create a unique company for this test
    company_to_find = CompanyNode.create(name: 'FindMe Inc', founding_year: 2001, active: false)
    assert company_to_find.persisted?, 'Company should be persisted after create'
    refute_nil company_to_find.internal_id, 'Persisted company should have an internal_id'

    # Fetch the company using the internal ID
    found_company = CompanyNode.find(company_to_find.internal_id)

    assert_instance_of CompanyNode, found_company, 'Should return a CompanyNode instance'
    assert found_company.persisted?, 'Found company should be persisted'
    assert_equal company_to_find.internal_id, found_company.internal_id,
                 'Found company should have the correct internal_id'

    assert_equal 'FindMe Inc', found_company.name
    assert_equal 2001, found_company.founding_year
    assert_equal false, found_company.active
  end

  def test_where_fetches_multiple_nodes
    # Fetch all companies (Acme Corp and Globex Inc)
    results = CompanyNode.all.to_a # Use .to_a to execute

    assert_equal 2, results.length, 'Should find two companies'
    names = results.map(&:name).sort
    assert_equal ['Acme Corp', 'Globex Inc'], names
  end

  def test_where_with_boolean
    # Fetch active companies (only Acme Corp)
    results = CompanyNode.where(active: true).to_a

    assert_equal 1, results.length, 'Should find only one active company'
    assert_equal 'Acme Corp', results.first.name
  end

  private

  def connection
    CompanyNode.connection
  end

  # Helper to clear the Neo4j database between tests
  def clear_database
    # Force write access mode for clearing
    connection.send :wipe_database, confirm: 'yes, really'
  end
end
