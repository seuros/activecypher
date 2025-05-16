# frozen_string_literal: true

require 'test_helper'

class NodeLabelTest < ActiveSupport::TestCase
  test 'PersonNode has default label based on class name' do
    assert_equal [:Person], PersonNode.labels
    assert_equal :Person, PersonNode.label_name
  end

  test 'HobbyNode has single custom label' do
    assert_equal [:Activity], HobbyNode.labels
    assert_equal :Activity, HobbyNode.label_name
  end

  test 'ConspiracyNode has two labels' do
    assert_includes ConspiracyNode.labels, :Conspiracy
    assert_includes ConspiracyNode.labels, :Theory
    assert_equal 2, ConspiracyNode.labels.size

    # The first label is used as the primary label
    assert_equal :Conspiracy, ConspiracyNode.label_name
  end

  test 'MultiLabelTheoryNode has three labels' do
    assert_includes MultiLabelTheoryNode.labels, :FirstLabel
    assert_includes MultiLabelTheoryNode.labels, :SecondLabel
    assert_includes MultiLabelTheoryNode.labels, :ThirdLabel
    assert_equal 3, MultiLabelTheoryNode.labels.size

    # The first label is used as the primary label
    assert_equal :FirstLabel, MultiLabelTheoryNode.label_name
  end

  test 'label_name returns the first custom label when multiple labels exist' do
    # ConspiracyNode has two labels: :Conspiracy and :Theory
    # :Conspiracy should be the first one (primary label)
    assert_equal :Conspiracy, ConspiracyNode.label_name

    # MultiLabelTheoryNode has three labels: :FirstLabel, :SecondLabel, :ThirdLabel
    # :FirstLabel should be the primary label
    assert_equal :FirstLabel, MultiLabelTheoryNode.label_name
  end

  test 'label_name returns the class element name when no custom labels exist' do
    assert_equal :Person, PersonNode.label_name
  end

  test 'custom labels can be inspected' do
    assert_empty PersonNode.custom_labels
    assert_equal [:Activity], HobbyNode.custom_labels
    assert_equal %i[Conspiracy Theory], ConspiracyNode.custom_labels
    assert_equal %i[FirstLabel SecondLabel ThirdLabel], MultiLabelTheoryNode.custom_labels
  end
end
