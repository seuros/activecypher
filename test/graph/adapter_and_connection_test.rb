# frozen_string_literal: true

require 'test_helper'

GRAPH_CLASSES = [
  AnimalNode,
  ApplicationGraphNode,
  ApplicationGraphRelationship,
  BelievesInRel,
  CallLogNode,
  CallbackPerson,
  CarNode,
  CompanyNode,
  ConspiracyNode,
  DefaultLabelNode,
  EnjoysRel,
  HobbyNode,
  MultiLabelTheoryNode,
  Neo4jRecord,
  OwnsPetRel,
  PersonNode,
  PetNode
].freeze

class AdapterAndConnectionTest < ActiveSupport::TestCase
  def test_graph_classes_have_correct_adapter_and_connection
    expected_class_connections = {
      AnimalNode => :primary,
      ApplicationGraphNode => :primary,
      ApplicationGraphRelationship => nil,
      BelievesInRel => nil,
      EnjoysRel => nil,
      OwnsPetRel => nil,
      CallbackPerson => :primary,
      CarNode => :primary,
      ConspiracyNode => :primary,
      DefaultLabelNode => :primary,
      HobbyNode => :primary,
      MultiLabelTheoryNode => :primary,
      PersonNode => :primary,
      PetNode => :primary,
      CallLogNode => :neo4j,
      CompanyNode => :neo4j,
      Neo4jRecord => :neo4j
    }

    GRAPH_CLASSES.each do |klass|
      expected_adapter = expected_class_connections[klass]

      # Relationship classes don't have connects_to_mappings
      if klass < ActiveCypher::Relationship
        assert_nil expected_adapter, "#{klass.name} is a relationship class and should not have a connection mapping"
        next
      end

      mapping = klass.connects_to_mappings[:writing]

      if expected_adapter.nil?
        assert_nil mapping, "#{klass.name} should have connects_to_mappings[:writing] == nil, got #{mapping.inspect}"
      else
        assert_equal expected_adapter, mapping,
                     "#{klass.name} should have connects_to_mappings[:writing] == #{expected_adapter.inspect}, got #{mapping.inspect}"
      end
    end
  end

  def test_person_and_company_node_connection_objects_in_isolation
    person_conn = PersonNode.connection
    company_conn = CompanyNode.connection

    refute_equal person_conn.object_id, company_conn.object_id, 'PersonNode and CompanyNode should not share the same connection object in isolation'
    refute person_conn.equal?(company_conn), 'PersonNode and CompanyNode should not share the same connection instance in isolation'
    refute_same person_conn, company_conn, 'PersonNode and CompanyNode should not share the same connection instance in isolation'
  end

  def test_person_and_company_node_do_not_share_connection_object
    person_conn = PersonNode.connection
    company_conn = CompanyNode.connection

    refute_equal person_conn.object_id, company_conn.object_id, 'PersonNode and CompanyNode should not share the same connection object'
    refute person_conn.equal?(company_conn), 'PersonNode and CompanyNode should not share the same connection instance'
    refute_same person_conn, company_conn, 'PersonNode and CompanyNode should not share the same connection instance'
  end

  def test_graph_classes_inherit_from_correct_base
    # Check inheritance for each class
    assert AnimalNode < ApplicationGraphNode
    assert CarNode < ApplicationGraphNode
    assert ConspiracyNode < ApplicationGraphNode
    assert DefaultLabelNode < ApplicationGraphNode
    assert HobbyNode < ApplicationGraphNode
    assert MultiLabelTheoryNode < ApplicationGraphNode
    assert PersonNode < ApplicationGraphNode
    assert PetNode < ApplicationGraphNode

    assert BelievesInRel < ApplicationGraphRelationship
    assert EnjoysRel < ApplicationGraphRelationship
    assert OwnsPetRel < ApplicationGraphRelationship

    assert CallLogNode < Neo4jRecord
    assert CompanyNode < Neo4jRecord

    assert CallbackPerson < PersonNode
  end
end
