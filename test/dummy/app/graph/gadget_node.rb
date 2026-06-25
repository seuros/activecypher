# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["Gadget"]
#
# attributes = [{ name = "name", type = "string" }]
#
# [associations]
# widget = { macro = "belongs_to", class = "WidgetNode", rel = "HAS_GADGET", direction = "in" }
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class GadgetNode < ApplicationGraphNode

  attribute :name, :string

  belongs_to :widget,
             class_name: 'WidgetNode',
             relationship: 'HAS_GADGET',
             direction: :in
end
