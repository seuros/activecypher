# frozen_string_literal: true

require 'test_helper'

class NodeLabelsIntegrationTest < ActiveSupport::TestCase
  setup do
    # Clean up any existing nodes before each test
    ConspiracyNode.connection.execute_cypher('MATCH (n:Conspiracy:Theory) DETACH DELETE n')
    HobbyNode.connection.execute_cypher('MATCH (n:Activity) DETACH DELETE n')
    MultiLabelTheoryNode.connection.execute_cypher('MATCH (n:FirstLabel:SecondLabel:ThirdLabel) DETACH DELETE n')
  end

  test 'nodes with multiple labels are created with all labels' do
    # Create a conspiracy node with multiple labels
    conspiracy = ConspiracyNode.create(
      name: "Birds Aren't Real",
      description: 'Birds are actually government drones',
      believability_index: 8
    )

    # Query to check if the node has both labels
    result = ConspiracyNode.connection.execute_cypher(
      'MATCH (n:Conspiracy:Theory) WHERE elementId(n) = $id RETURN n',
      { id: conspiracy.internal_id }
    )

    assert_equal 1, result.size
    # Access property in Neo4j bolt format array structure
    node_data = result.first[:n]
    # For Neo4j bolt format: [78, [id, [labels], {properties}, "element_id"]]
    properties = node_data[1][2]
    assert_equal "Birds Aren't Real", properties[:name]
  end

  test 'nodes with custom labels are created with the custom label' do
    # Create a hobby node with a custom label
    hobby = HobbyNode.create(
      name: 'Bird Watching',
      category: 'Outdoor',
      skill_level: 'Intermediate'
    )

    # Query using the custom label
    result = HobbyNode.connection.execute_cypher(
      'MATCH (n:Activity) WHERE elementId(n) = $id RETURN n',
      { id: hobby.internal_id }
    )

    assert_equal 1, result.size
    # Access property in Neo4j bolt format array structure
    node_data = result.first[:n]
    # For Neo4j bolt format: [78, [id, [labels], {properties}, "element_id"]]
    properties = node_data[1][2]
    assert_equal 'Bird Watching', properties[:name]

    # Verify it doesn't have the default class name label
    alt_result = HobbyNode.connection.execute_cypher(
      'MATCH (n:hobby_node) WHERE elementId(n) = $id RETURN n',
      { id: hobby.internal_id }
    )

    assert_empty alt_result
  end

  test 'nodes with multiple labels can be queried by any of their labels' do
    # Create a test node
    conspiracy = ConspiracyNode.create(
      name: 'Flat Earth',
      description: 'The earth is a flat disc',
      believability_index: 2
    )

    # Query using the first label
    conspiracy_result = ConspiracyNode.connection.execute_cypher(
      'MATCH (n:Conspiracy) WHERE elementId(n) = $id RETURN n',
      { id: conspiracy.internal_id }
    )

    # Query using the second label
    theory_result = ConspiracyNode.connection.execute_cypher(
      'MATCH (n:Theory) WHERE elementId(n) = $id RETURN n',
      { id: conspiracy.internal_id }
    )

    assert_equal 1, conspiracy_result.size
    assert_equal 1, theory_result.size

    # Access property in Neo4j bolt format array structure
    conspiracy_node = conspiracy_result.first[:n]
    theory_node = theory_result.first[:n]
    # For Neo4j bolt format: [78, [id, [labels], {properties}, "element_id"]]
    conspiracy_properties = conspiracy_node[1][2]
    theory_properties = theory_node[1][2]

    assert_equal 'Flat Earth', conspiracy_properties[:name]
    assert_equal 'Flat Earth', theory_properties[:name]
  end

  test 'find method works with nodes having multiple labels' do
    # Create a node and find it
    conspiracy = ConspiracyNode.create(
      name: 'Moon Landing Hoax',
      description: 'Moon landing was filmed in a studio',
      believability_index: 4
    )

    found_conspiracy = ConspiracyNode.find(conspiracy.internal_id)

    assert_equal conspiracy.name, found_conspiracy.name
    assert_equal conspiracy.internal_id, found_conspiracy.internal_id
  end

  test 'update works with nodes having multiple labels' do
    # Create and then update a conspiracy node
    conspiracy = ConspiracyNode.create(
      name: 'Reptilian Elite',
      description: 'World leaders are reptiles in disguise',
      believability_index: 3
    )

    # Update the node
    conspiracy.update(believability_index: 5, description: 'Updated description')

    # Find it again to verify update
    updated = ConspiracyNode.find(conspiracy.internal_id)

    assert_equal 'Reptilian Elite', updated.name
    assert_equal 'Updated description', updated.description
    assert_equal 5, updated.believability_index
  end

  # Add teardown to reset connection state between tests
  teardown do
    # Reset connections to clear any pending transactions
    ConspiracyNode.connection.reset! if ConspiracyNode.respond_to?(:connection) && ConspiracyNode.connection.respond_to?(:reset!)
    HobbyNode.connection.reset! if HobbyNode.respond_to?(:connection) && HobbyNode.connection.respond_to?(:reset!)
    MultiLabelTheoryNode.connection.reset! if MultiLabelTheoryNode.respond_to?(:connection) && MultiLabelTheoryNode.connection.respond_to?(:reset!)
  end

  test 'destroy works with nodes having multiple labels' do
    # Create and then destroy a node
    conspiracy = ConspiracyNode.create(
      name: 'Chemtrails',
      description: 'Airplane contrails contain chemicals',
      believability_index: 6
    )

    assert conspiracy.destroy

    # Verify it's gone
    assert_raises ActiveCypher::RecordNotFound do
      ConspiracyNode.find(conspiracy.internal_id)
    end
  end

  test 'nodes with three labels are created with all labels' do
    # Create a node with three labels
    theory = MultiLabelTheoryNode.create(
      name: 'Grand Unified Theory',
      description: 'Physics theory that unifies fundamental forces',
      level: 10
    )

    # Query to check if the node has all three labels
    result = MultiLabelTheoryNode.connection.execute_cypher(
      'MATCH (n:FirstLabel:SecondLabel:ThirdLabel) WHERE elementId(n) = $id RETURN n',
      { id: theory.internal_id }
    )

    assert_equal 1, result.size

    # Access property in Neo4j bolt format array structure
    node_data = result.first[:n]
    # For Neo4j bolt format: [78, [id, [labels], {properties}, "element_id"]]
    properties = node_data[1][2]
    assert_equal 'Grand Unified Theory', properties[:name]
  end

  test 'nodes with three labels can be queried by any of their labels' do
    # Create a node with three labels
    theory = MultiLabelTheoryNode.create(
      name: 'String Theory',
      description: 'Theoretical framework in physics',
      level: 9
    )

    # Query using each of the three labels
    first_result = MultiLabelTheoryNode.connection.execute_cypher(
      'MATCH (n:FirstLabel) WHERE elementId(n) = $id RETURN n',
      { id: theory.internal_id }
    )

    second_result = MultiLabelTheoryNode.connection.execute_cypher(
      'MATCH (n:SecondLabel) WHERE elementId(n) = $id RETURN n',
      { id: theory.internal_id }
    )

    third_result = MultiLabelTheoryNode.connection.execute_cypher(
      'MATCH (n:ThirdLabel) WHERE elementId(n) = $id RETURN n',
      { id: theory.internal_id }
    )

    assert_equal 1, first_result.size
    assert_equal 1, second_result.size
    assert_equal 1, third_result.size

    # Access property in Neo4j bolt format array structure
    first_node = first_result.first[:n]
    second_node = second_result.first[:n]
    third_node = third_result.first[:n]

    # For Neo4j bolt format: [78, [id, [labels], {properties}, "element_id"]]
    first_properties = first_node[1][2]
    second_properties = second_node[1][2]
    third_properties = third_node[1][2]

    assert_equal 'String Theory', first_properties[:name]
    assert_equal 'String Theory', second_properties[:name]
    assert_equal 'String Theory', third_properties[:name]
  end
end
