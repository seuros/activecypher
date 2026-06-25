# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["Road"]
#
# attributes = [{ name = "name", type = "string" }]
#
# [associations]
# city = { macro = "has_one", class = "CityNode", rel = "LEADS_TO" }
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class RoadNode < ApplicationGraphNode

  attribute :name, :string

  has_one :city,
          class_name: 'CityNode',
          relationship: 'LEADS_TO',
          direction: :out
end
