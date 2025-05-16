# frozen_string_literal: true

require 'test_helper'

class NodeLabelTest < ActiveSupport::TestCase
  test 'PersonNode has default label based on class name' do
    puts "\nPersonNode custom_labels: #{PersonNode.custom_labels.inspect}"
    puts "PersonNode labels: #{PersonNode.labels.inspect}"
    puts "PersonNode label_name: #{PersonNode.label_name.inspect}"
    assert_equal [:person_node], PersonNode.labels
    assert_equal :person_node, PersonNode.label_name
  end

  test 'HobbyNode has single custom label' do
    puts "\nHobbyNode custom_labels: #{HobbyNode.custom_labels.inspect}"
    puts "HobbyNode labels: #{HobbyNode.labels.inspect}"
    puts "HobbyNode label_name: #{HobbyNode.label_name.inspect}"
    assert_equal [:Activity], HobbyNode.labels
    assert_equal :Activity, HobbyNode.label_name
  end

  test 'ConspiracyNode has two labels' do
    puts "\nConspiracyNode custom_labels: #{ConspiracyNode.custom_labels.inspect}"
    puts "ConspiracyNode labels: #{ConspiracyNode.labels.inspect}"
    puts "ConspiracyNode label_name: #{ConspiracyNode.label_name.inspect}"
    assert_includes ConspiracyNode.labels, :Conspiracy
    assert_includes ConspiracyNode.labels, :Theory
    assert_equal 2, ConspiracyNode.labels.size

    # The first label is used as the primary label
    assert_equal :Conspiracy, ConspiracyNode.label_name
  end

  test 'MultiLabelTheoryNode has three labels' do
    puts "\nMultiLabelTheoryNode custom_labels: #{MultiLabelTheoryNode.custom_labels.inspect}"
    puts "MultiLabelTheoryNode labels: #{MultiLabelTheoryNode.labels.inspect}"
    puts "MultiLabelTheoryNode label_name: #{MultiLabelTheoryNode.label_name.inspect}"
    assert_includes MultiLabelTheoryNode.labels, :FirstLabel
    assert_includes MultiLabelTheoryNode.labels, :SecondLabel
    assert_includes MultiLabelTheoryNode.labels, :ThirdLabel
    assert_equal 3, MultiLabelTheoryNode.labels.size

    # The first label is used as the primary label
    assert_equal :FirstLabel, MultiLabelTheoryNode.label_name
  end

  test 'label_name returns the first custom label when multiple labels exist' do
    puts "\nChecking primary labels (first custom label)"
    # ConspiracyNode has two labels: :Conspiracy and :Theory
    # :Conspiracy should be the first one (primary label)
    puts "ConspiracyNode label_name: #{ConspiracyNode.label_name.inspect}"
    assert_equal :Conspiracy, ConspiracyNode.label_name

    # MultiLabelTheoryNode has three labels: :FirstLabel, :SecondLabel, :ThirdLabel
    # :FirstLabel should be the primary label
    puts "MultiLabelTheoryNode label_name: #{MultiLabelTheoryNode.label_name.inspect}"
    assert_equal :FirstLabel, MultiLabelTheoryNode.label_name
  end

  test 'label_name returns the class element name when no custom labels exist' do
    puts "\nPersonNode with no custom labels:"
    puts "PersonNode label_name: #{PersonNode.label_name.inspect}"
    assert_equal :person_node, PersonNode.label_name
  end

  test 'custom labels can be inspected' do
    puts "\nInspecting custom labels on various models:"
    puts "PersonNode custom_labels: #{PersonNode.custom_labels.inspect}"
    puts "HobbyNode custom_labels: #{HobbyNode.custom_labels.inspect}"
    puts "ConspiracyNode custom_labels: #{ConspiracyNode.custom_labels.inspect}"
    puts "MultiLabelTheoryNode custom_labels: #{MultiLabelTheoryNode.custom_labels.inspect}"

    assert_empty PersonNode.custom_labels
    assert_equal Set[:Activity], HobbyNode.custom_labels
    assert_equal Set[:Conspiracy, :Theory], ConspiracyNode.custom_labels
    assert_equal Set[:FirstLabel, :SecondLabel, :ThirdLabel], MultiLabelTheoryNode.custom_labels
  end
end
