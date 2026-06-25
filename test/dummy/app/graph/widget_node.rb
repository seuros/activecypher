# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["Widget"]
#
# attributes = [{ name = "name", type = "string" }]
#
# [associations]
# gadget = { macro = "has_one", class = "GadgetNode", rel = "HAS_GADGET" }
# supplier = { macro = "has_one", class = "GadgetNode", rel = "SUPPLIES", direction = "in" }
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class WidgetNode < ApplicationGraphNode

  attribute :name, :string

  has_one :gadget,
          class_name: 'GadgetNode',
          relationship: 'HAS_GADGET',
          direction: :out

  # Incoming direction: (gadget)-[:SUPPLIES]->(widget)
  has_one :supplier,
          class_name: 'GadgetNode',
          relationship: 'SUPPLIES',
          direction: :in
end
