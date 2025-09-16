# frozen_string_literal: true

require 'test_helper'
require 'minitest/autorun'

class Neo4jUuidElementIdTest < Minitest::Test
  def test_with_direct_id_quotes_uuid_element_ids
    adapter = ActiveCypher::ConnectionAdapters::Neo4jAdapter
    uuid_element_id = "4:44c8c9cb-f37c-4132-b230-b42995cbd140:18"

    result = adapter.with_direct_id(uuid_element_id)
    expected = "elementId(r) = '4:44c8c9cb-f37c-4132-b230-b42995cbd140:18'"

    assert_equal expected, result, "Should properly quote UUID-based element IDs"
  end

  def test_with_direct_node_ids_quotes_uuid_element_ids
    adapter = ActiveCypher::ConnectionAdapters::Neo4jAdapter
    from_id = "4:44c8c9cb-f37c-4132-b230-b42995cbd140:18"
    to_id = "4:44c8c9cb-f37c-4132-b230-b42995cbd140:19"

    result = adapter.with_direct_node_ids(from_id, to_id)
    expected = "elementId(p) = '4:44c8c9cb-f37c-4132-b230-b42995cbd140:18' AND elementId(h) = '4:44c8c9cb-f37c-4132-b230-b42995cbd140:19'"

    assert_equal expected, result, "Should properly quote both UUID-based element IDs"
  end

  def test_node_id_equals_value_quotes_uuid_element_ids
    adapter = ActiveCypher::ConnectionAdapters::Neo4jAdapter
    uuid_element_id = "4:44c8c9cb-f37c-4132-b230-b42995cbd140:18"

    result = adapter.node_id_equals_value("n", uuid_element_id)
    expected = "elementId(n) = '4:44c8c9cb-f37c-4132-b230-b42995cbd140:18'"

    assert_equal expected, result, "Should properly quote UUID-based element IDs"
  end

  def test_relationship_create_query_with_uuid_element_ids
    # Mock nodes with UUID element IDs
    from_node = Minitest::Mock.new
    from_node.expect :persisted?, true
    from_node.expect :internal_id, "4:44c8c9cb-f37c-4132-b230-b42995cbd140:18"

    to_node = Minitest::Mock.new
    to_node.expect :persisted?, true
    to_node.expect :internal_id, "4:44c8c9cb-f37c-4132-b230-b42995cbd140:19"

    adapter = ActiveCypher::ConnectionAdapters::Neo4jAdapter

    # Test the query generation
    id_clause = adapter.with_direct_node_ids(from_node.internal_id, to_node.internal_id)
    query = "MATCH (p), (h) WHERE #{id_clause}"

    expected = "MATCH (p), (h) WHERE elementId(p) = '4:44c8c9cb-f37c-4132-b230-b42995cbd140:18' AND elementId(h) = '4:44c8c9cb-f37c-4132-b230-b42995cbd140:19'"

    assert_equal expected, query, "Generated query should have properly quoted UUID element IDs"

    # Verify the query doesn't have unquoted colons that would cause parsing errors
    refute_match(/elementId\([^)]+\) = 4:/, query, "Element IDs should be quoted to prevent parsing errors")
  end
end