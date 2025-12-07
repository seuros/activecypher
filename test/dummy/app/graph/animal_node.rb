# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["Animal", "LivingBeing"]
#
# attributes = [{ name = "name", type = "string" }, { name = "species", type = "string" }]
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class AnimalNode < ApplicationGraphNode

  # Define multiple labels
  label :Animal
  label :LivingBeing

  attribute :name, :string
  attribute :species, :string
end