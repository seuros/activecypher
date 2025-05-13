# frozen_string_literal: true

require 'test_helper'

class LabelTest < ActiveSupport::TestCase
  test 'models use class name as default label' do
    assert_equal [:person_node], PersonNode.labels
    assert_equal :person_node, PersonNode.label_name
  end

  test 'models can define a custom label' do
    assert_equal [:Activity], HobbyNode.labels
    assert_equal :Activity, HobbyNode.label_name
  end

  test 'models can have multiple labels' do
    assert_includes ConspiracyNode.labels, :Conspiracy
    assert_includes ConspiracyNode.labels, :Theory
    assert_equal 2, ConspiracyNode.labels.size

    # The first label is used as the primary label
    assert_equal :Conspiracy, ConspiracyNode.label_name
  end

  test 'label method adds labels to the set' do
    # Store original labels
    original_labels = PersonNode.custom_labels.dup

    # Add a label dynamically
    PersonNode.label(:DynamicLabel)

    assert_includes PersonNode.labels, :DynamicLabel

    # Reset for other tests
    PersonNode.custom_labels = original_labels
  end

  test 'duplicate labels are added only once' do
    # Store original labels
    original_labels = PersonNode.custom_labels.dup

    # Try to add the same label multiple times
    PersonNode.label(:SameLabel)
    PersonNode.label(:SameLabel)
    PersonNode.label(:SameLabel)

    # Check there's only one occurrence
    assert_equal 1, PersonNode.custom_labels.count(:SameLabel)

    # Reset for other tests
    PersonNode.custom_labels = original_labels
  end
end
