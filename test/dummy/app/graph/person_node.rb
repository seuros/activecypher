# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["Person"]
#
# attributes = [{ name = "id", type = "string" }, { name = "name", type = "string" }, { name = "age", type = "integer" }, { name = "active", type = "boolean" }]
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class PersonNode < ApplicationGraphNode

  attribute :id, :string
  attribute :name, :string
  attribute :age, :integer
  attribute :active, :boolean, default: true

  validates :name, presence: true
end
