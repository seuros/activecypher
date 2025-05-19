# frozen_string_literal: true

require 'test_helper'

class LabelIntegrationTest < ActiveSupport::TestCase
  setup do
    ApplicationGraphNode.connection.execute_cypher('MATCH (n) DETACH DELETE n')
  end

  test 'nodes are created with all custom labels' do
    # Create a node with multiple labels
    animal = AnimalNode.create(name: 'Leo', species: 'Lion')

    # Verify node was created with proper data
    found_animal = AnimalNode.find(animal.internal_id)
    assert_equal 'Leo', found_animal.name

    # Verify both labels exist via direct Cypher
    result = AnimalNode.connection.execute_cypher(
      "MATCH (n:Animal:LivingBeing) WHERE id(n) = #{animal.internal_id} RETURN count(n) as count"
    )

    assert_equal 1, result.first[:count]
  end

  test "nodes with custom label don't have default class name label" do
    # Create a node with a custom label
    car = CarNode.create(make: 'Toyota', model: 'Prius')

    # Find the car using model methods
    found_car = CarNode.find(car.internal_id)
    assert_equal 'Toyota', found_car.make
    assert_equal 'Prius', found_car.model

    # Verify it doesn't have the default class name label

    missing_result = CarNode.connection.execute_cypher(
      "MATCH (n:car_node) WHERE id(n) = #{car.internal_id} RETURN n"
    )

    assert_empty missing_result
  end

  test 'nodes with default label use class name' do
    # Create a node with default label
    node = DefaultLabelNode.create(name: 'Default Node')

    # Find the node using model methods
    found_node = DefaultLabelNode.find(node.internal_id)
    assert_equal 'Default Node', found_node.name
  end

  test 'nodes with multiple labels can be queried by any of their labels' do
    # Create a test node
    animal = AnimalNode.create(name: 'Rex', species: 'Dog')

    # Find using model method to verify basic data
    found_animal = AnimalNode.find(animal.internal_id)
    assert_equal 'Rex', found_animal.name

    # Query using each label separately to verify both labels work
    animal_result = AnimalNode.connection.execute_cypher(
      "MATCH (n:Animal) WHERE id(n) = #{animal.internal_id} RETURN count(n) as count"
    )

    living_being_result = AnimalNode.connection.execute_cypher(
      "MATCH (n:LivingBeing) WHERE id(n) = #{animal.internal_id} RETURN count(n) as count"
    )

    # Check results
    assert_equal 1, animal_result.first[:count]
    assert_equal 1, living_being_result.first[:count]
  end

  test 'find method works with custom labeled nodes' do
    # Create nodes and find them
    animal = AnimalNode.create(name: 'Whiskers', species: 'Cat')
    car = CarNode.create(make: 'Honda', model: 'Civic')

    found_animal = AnimalNode.find(animal.internal_id)
    found_car = CarNode.find(car.internal_id)

    assert_equal animal.name, found_animal.name
    assert_equal animal.internal_id, found_animal.internal_id
    assert_equal car.make, found_car.make
    assert_equal car.model, found_car.model
  end

  test 'update works with custom labeled nodes' do
    # Create and then update nodes
    animal = AnimalNode.create(name: 'Dumbo', species: 'Elephant')
    car = CarNode.create(make: 'Ford', model: 'Focus')

    # Update the nodes
    animal.update(species: 'African Elephant')
    car.update(model: 'Mustang')

    # Find them again to verify update
    updated_animal = AnimalNode.find(animal.internal_id)
    updated_car = CarNode.find(car.internal_id)

    assert_equal 'Dumbo', updated_animal.name
    assert_equal 'African Elephant', updated_animal.species
    assert_equal 'Ford', updated_car.make
    assert_equal 'Mustang', updated_car.model
  end

  test 'destroy works with custom labeled nodes' do
    # Create and then destroy nodes
    animal = AnimalNode.create(name: 'Nemo', species: 'Fish')
    car = CarNode.create(make: 'Tesla', model: 'Model 3')

    # Verify nodes exist before destroying them

    AnimalNode.connection.execute_cypher(
      "MATCH (n:Animal:LivingBeing) WHERE id(n) = #{animal.internal_id} RETURN count(n) as count"
    )
    CarNode.connection.execute_cypher(
      "MATCH (n:Vehicle) WHERE id(n) = #{car.internal_id} RETURN count(n) as count"
    )

    # Explicitly destroy and check results
    result1 = animal.destroy
    result2 = car.destroy

    assert result1, 'Animal node should be destroyed successfully'
    assert result2, 'Car node should be destroyed successfully'

    # Verify they're gone
    assert_raises ActiveCypher::RecordNotFound do
      AnimalNode.find(animal.internal_id)
    end

    assert_raises ActiveCypher::RecordNotFound do
      CarNode.find(car.internal_id)
    end
  end
end
