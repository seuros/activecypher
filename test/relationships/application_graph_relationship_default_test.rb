# frozen_string_literal: true

require 'test_helper'

class ApplicationGraphRelationshipDefaultTest < ActiveSupport::TestCase
  def test_node_base_class_defaults_by_convention
    rel_class = ApplicationGraphRelationship
    node_class_name = rel_class.name.sub(/Relationship\z/, 'Node')
    node_class = node_class_name.constantize

    assert_equal node_class, rel_class.node_base_class,
                 "#{rel_class.name}.node_base_class should default to #{node_class.name} by convention"
    assert rel_class.node_base_class.abstract_class?,
           'Default node_base_class should be abstract'
  end

  def test_connection_delegates_to_node_base_class
    rel_class = ApplicationGraphRelationship
    node_class = rel_class.node_base_class
    assert_equal node_class.connection, rel_class.connection,
                 "#{rel_class.name}.connection should delegate to #{node_class.name}.connection"
  end
end
