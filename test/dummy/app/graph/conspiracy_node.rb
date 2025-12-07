# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["Conspiracy", "Theory"]
#
# attributes = [{ name = "name", type = "string" }, { name = "description", type = "string" }, { name = "believability_index", type = "integer" }]
#
# [associations]
# followers = { macro = "has_many", class = "PersonNode", rel = "BELIEVES_IN", direction = "in", relationship_class = "BelievesInRel" }
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class ConspiracyNode < ApplicationGraphNode

  # Define multiple labels
  label :Conspiracy
  label :Theory

  attribute :name,         :string
  attribute :description,  :string
  attribute :believability_index, :integer # From 0 (flat earth) to 10 (birds aren't real)

  has_many :followers,
           class_name: 'PersonNode',
           relationship: 'BELIEVES_IN',
           direction: :in,
           relationship_class: 'BelievesInRel'
end
