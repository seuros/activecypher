# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["City"]
#
# attributes = [{ name = "name", type = "string" }]
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class CityNode < ApplicationGraphNode

  attribute :name, :string
end
