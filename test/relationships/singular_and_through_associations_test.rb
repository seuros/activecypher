# frozen_string_literal: true

require 'test_helper'

# End-to-end coverage for the singular (has_one / belongs_to writer) and
# has_many :through association query paths. These were previously dead code
# (they called fluent methods that do not exist on Cyrel::Pattern::Node) and
# had no tests. Exercises the real dummy-app models against the live database.
class SingularAndThroughAssociationsTest < ActiveSupport::TestCase
  setup do
    WidgetNode.connection.execute_cypher('MATCH (n) DETACH DELETE n')
  end

  test 'has_one writer creates an outgoing relationship, reader reads it, nil deletes it' do
    widget = WidgetNode.create(name: 'W')
    gadget = GadgetNode.create(name: 'G')

    widget.gadget = gadget
    assert_equal 1, rel_count('HAS_GADGET', widget, gadget)

    reloaded = WidgetNode.find(widget.internal_id)
    assert_equal gadget.internal_id, reloaded.gadget&.internal_id, 'reader should follow :out relationship'

    widget.gadget = nil
    assert_equal 0, rel_count('HAS_GADGET', widget, gadget), 'assigning nil should delete the relationship'
  end

  test 'has_one reader follows an incoming relationship for direction :in' do
    widget = WidgetNode.create(name: 'W3')
    supplier = GadgetNode.create(name: 'S')

    # direction :in means (supplier)-[:SUPPLIES]->(widget)
    create_rel('SUPPLIES', supplier, widget)

    reloaded = WidgetNode.find(widget.internal_id)
    assert_equal supplier.internal_id, reloaded.supplier&.internal_id
  end

  test 'belongs_to writer creates the relationship in the owner direction' do
    widget = WidgetNode.create(name: 'W2')
    gadget = GadgetNode.create(name: 'G2')

    # GadgetNode belongs_to :widget with direction :in => (widget)-[:HAS_GADGET]->(gadget)
    gadget.widget = widget
    assert_equal 1, rel_count('HAS_GADGET', widget, gadget)

    reloaded = GadgetNode.find(gadget.internal_id)
    assert_equal widget.internal_id, reloaded.widget&.internal_id, 'belongs_to reader should find the owner'
  end

  test 'has_many :through traverses two hops' do
    town = TownNode.create(name: 'Springfield')
    road = RoadNode.create(name: 'Route 66')
    city = CityNode.create(name: 'Capital')

    create_rel('BUILT', town, road)
    create_rel('LEADS_TO', road, city)

    found = town.cities.to_a
    assert_equal [city.internal_id], found.map(&:internal_id)
  end

  private

  def adapter = WidgetNode.connection.id_handler

  # NOTE: adapter.with_direct_node_ids hardcodes the aliases p (start) and h (end).
  def rel_count(type, from_node, to_node)
    WidgetNode.connection.execute_cypher(
      "MATCH (p)-[r:#{type}]->(h)
       WHERE #{adapter.with_direct_node_ids(from_node.internal_id, to_node.internal_id)}
       RETURN COUNT(r) AS count"
    )[0][:count]
  end

  def create_rel(type, from_node, to_node)
    WidgetNode.connection.execute_cypher(
      "MATCH (p), (h)
       WHERE #{adapter.with_direct_node_ids(from_node.internal_id, to_node.internal_id)}
       CREATE (p)-[:#{type}]->(h)"
    )
  end
end
