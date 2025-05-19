# frozen_string_literal: true

require 'test_helper'

class NodeBuilderTest < ActiveSupport::TestCase
  def setup
    ActiveCypher::Fixtures::Registry.reset!
    PersonNode.connection.execute_cypher('MATCH (n:Person) DETACH DELETE n')
  end

  def test_build_creates_person_node_and_registers_it
    instance = ActiveCypher::Fixtures::NodeBuilder.build(
      :john,
      PersonNode,
      name: 'John',
      age: 42
    )

    assert instance.is_a?(PersonNode), "Expected PersonNode, got #{instance.class}"
    assert_equal 'John', instance.name
    assert_equal 42, instance.age
    assert instance.internal_id.is_a?(Integer), "Expected integer internal_id, got #{instance.internal_id.inspect}"

    # Confirm node exists in DB
    result = PersonNode.connection.execute_cypher(<<~CYPHER, name: 'John')
      MATCH (n:Person {name: $name})
      RETURN count(n) AS count
    CYPHER
    assert result.first[:count].positive?, "Expected node 'John' to exist in DB"

    # Confirm registration
    registry_obj = ActiveCypher::Fixtures::Registry.get(:john)
    assert_equal instance, registry_obj, 'Registry should store the same object'
  end
end
