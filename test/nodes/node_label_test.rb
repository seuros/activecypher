# frozen_string_literal: true

require 'test_helper'

class NodeLabelTest < ActiveSupport::TestCase
  test 'default labels based on class name' do
    # PersonNode uses the class name as its default label
    assert_equal [:Person], PersonNode.labels
    assert_equal :Person, PersonNode.label_name
  end

  test 'custom label defined' do
    # HobbyNode defines a custom label
    assert_equal [:Activity], HobbyNode.labels
    assert_equal :Activity, HobbyNode.label_name
  end

  test 'multiple labels with primary as the first label' do
    # ConspiracyNode has two labels, where the first is considered the primary label
    assert_includes ConspiracyNode.labels, :Conspiracy
    assert_includes ConspiracyNode.labels, :Theory
    assert_equal 2, ConspiracyNode.labels.size
    assert_equal :Conspiracy, ConspiracyNode.label_name
  end

  test 'multi-label theory node with three labels' do
    # MultiLabelTheoryNode has three custom labels; the first one is the primary label.
    assert_includes MultiLabelTheoryNode.labels, :FirstLabel
    assert_includes MultiLabelTheoryNode.labels, :SecondLabel
    assert_includes MultiLabelTheoryNode.labels, :ThirdLabel
    assert_equal 3, MultiLabelTheoryNode.labels.size
    assert_equal :FirstLabel, MultiLabelTheoryNode.label_name
  end

  test 'label method adds labels dynamically' do
    # Preserve original state to avoid side effects on other tests
    original_custom_labels = PersonNode.custom_labels.dup

    # Dynamically add a label and verify it was added
    PersonNode.label(:DynamicLabel)
    assert_includes PersonNode.labels, :DynamicLabel

    # Restore state
    PersonNode.custom_labels = original_custom_labels
  end

  test 'duplicate labels are added only once' do
    # Preserve original state to avoid side effects on other tests
    original_custom_labels = PersonNode.custom_labels.dup

    # Try adding the same label multiple times
    PersonNode.label(:SameLabel)
    PersonNode.label(:SameLabel)
    PersonNode.label(:SameLabel)

    # Ensure the duplicate label appears only once
    assert_equal 1, PersonNode.custom_labels.count(:SameLabel)

    # Restore state
    PersonNode.custom_labels = original_custom_labels
  end

  test 'custom labels can be inspected' do
    # Verify the custom_labels method returns the expected values
    assert_empty PersonNode.custom_labels
    assert_equal [:Activity], HobbyNode.custom_labels
    assert_equal %i[Conspiracy Theory], ConspiracyNode.custom_labels
    assert_equal %i[FirstLabel SecondLabel ThirdLabel], MultiLabelTheoryNode.custom_labels
  end
end
