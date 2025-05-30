# frozen_string_literal: true

require 'test_helper'

class SimpleNumericTest < ActiveSupport::TestCase
  def setup
    @node_data = {
      name: 'Numeric Test Node',
      integer_value: 42,
      float_value: 3.14159
    }
  end

  test 'can create node with integer attributes' do
    node = NumericTestNode.create!(@node_data)

    assert_equal 42, node.integer_value
    assert_instance_of Integer, node.integer_value
  end

  test 'can create node with float attributes' do
    node = NumericTestNode.create!(@node_data)

    assert_equal 3.14159, node.float_value
    assert_instance_of Float, node.float_value
  end

  test 'can persist and retrieve numeric values' do
    # Create and save node
    original_node = NumericTestNode.create!(@node_data)
    node_id = original_node.internal_id

    # Retrieve from database
    retrieved_node = NumericTestNode.find(node_id)

    # Verify all numeric types are preserved
    assert_equal 42, retrieved_node.integer_value
    assert_equal 3.14159, retrieved_node.float_value

    # Verify types are correct
    assert_instance_of Integer, retrieved_node.integer_value
    assert_instance_of Float, retrieved_node.float_value
  end

  test 'can query by numeric values' do
    # Create test nodes
    NumericTestNode.create!(name: 'Node A', integer_value: 10, float_value: 1.5)
    NumericTestNode.create!(name: 'Node B', integer_value: 20, float_value: 2.5)
    NumericTestNode.create!(name: 'Node C', integer_value: 30, float_value: 3.5)

    # Query by exact integer match
    exact_node = NumericTestNode.where(integer_value: 20).first
    assert_equal 'Node B', exact_node.name

    # Query by exact float match
    float_node = NumericTestNode.where(float_value: 2.5).first
    assert_equal 'Node B', float_node.name
  end

  test 'handles null numeric values' do
    node = NumericTestNode.create!(name: 'Null Test')

    assert_nil node.integer_value
    assert_nil node.float_value
  end

  test 'handles edge cases for numeric values' do
    edge_cases = {
      name: 'Edge Cases',
      integer_value: 0,
      float_value: 0.0
    }

    node = NumericTestNode.create!(edge_cases)

    assert_equal 0, node.integer_value
    assert_equal 0.0, node.float_value
  end

  test 'can update numeric values' do
    node = NumericTestNode.create!(@node_data)

    # Update values
    node.update(
      integer_value: 100,
      float_value: 2.718
    )

    # Find updated node and verify
    updated_node = NumericTestNode.find(node.internal_id)
    assert_equal 100, updated_node.integer_value
    assert_equal 2.718, updated_node.float_value
  end

  teardown do
    # Clean up test data
    test_names = ['Numeric Test Node', 'Node A', 'Node B', 'Node C', 'Null Test', 'Edge Cases']
    test_names.each do |name|
      NumericTestNode.where(name: name).each(&:destroy)
    end
  end
end
