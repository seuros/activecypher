# frozen_string_literal: true

require 'test_helper'

# Create a test class that will use a new connection pool
class TestNoConnectionNode < ActiveCypher::Base
  self.abstract_class = true

  # Override connection to ensure it returns nil
  def self.connection
    nil
  end
end

class AdapterClassTest < ActiveSupport::TestCase
  test 'node models respond to adapter_class' do
    assert_respond_to PersonNode, :adapter_class
    assert_respond_to PersonNode.new, :adapter_class
  end

  test 'relationship models respond to adapter_class' do
    assert_respond_to OwnsPetRel, :adapter_class
    assert_respond_to OwnsPetRel.new({}, from_node: PersonNode.new, to_node: PetNode.new), :adapter_class
  end

  test 'adapter_class returns correct adapter class' do
    # For default adapter
    adapter_class = PersonNode.adapter_class

    # Make sure we always get an adapter class back
    assert adapter_class.to_s.include?('Adapter'),
           "Expected adapter class name to include 'Adapter', got: #{adapter_class}"

    # Could be Neo4jAdapter or MemgraphAdapter depending on configuration
    assert_match(/(Neo4j|Memgraph)Adapter/, adapter_class.to_s)
  end

  test 'instance adapter_class returns same as class method' do
    person = PersonNode.new
    assert_equal PersonNode.adapter_class, person.adapter_class
  end

  test 'adapter_class handles nil connections gracefully' do
    assert_nil TestNoConnectionNode.adapter_class
    assert_nil TestNoConnectionNode.new.adapter_class
  end
end
