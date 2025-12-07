# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["DefaultLabel"]
#
# attributes = [{ name = "name", type = "string" }]
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class DefaultLabelNode < ApplicationGraphNode

  # Uses default label from class name (no explicit label declarations)
  attribute :name, :string
end