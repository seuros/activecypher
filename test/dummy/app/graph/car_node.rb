# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["Vehicle"]
#
# attributes = [{ name = "make", type = "string" }, { name = "model", type = "string" }]
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class CarNode < ApplicationGraphNode

  # Define a single custom label
  label :Vehicle

  attribute :make, :string
  attribute :model, :string
end