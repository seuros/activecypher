# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["Town"]
#
# attributes = [{ name = "name", type = "string" }]
#
# [associations]
# roads = { macro = "has_many", class = "RoadNode", rel = "BUILT" }
# cities = { macro = "has_many", class = "Cities", rel = "CITIES", through = "roads", source = "city" }
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class TownNode < ApplicationGraphNode

  attribute :name, :string

  has_many :roads,
           class_name: 'RoadNode',
           relationship: 'BUILT',
           direction: :out

  has_many :cities, through: :roads, source: :city
end
