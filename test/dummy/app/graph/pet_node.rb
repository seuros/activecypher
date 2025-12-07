# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["Pet", "Animal"]
#
# attributes = [{ name = "name", type = "string" }, { name = "species", type = "string" }, { name = "age", type = "integer" }]
#
# [associations]
# owners = { macro = "has_many", class = "PersonNode", rel = "OWNS_PET", direction = "in", relationship_class = "OwnsPetRel" }
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class PetNode < ApplicationGraphNode

  # Define custom labels
  label :Pet
  label :Animal

  attribute :name,     :string
  attribute :species,  :string
  attribute :age,      :integer

  has_many :owners,
           class_name: 'PersonNode',
           relationship: 'OWNS_PET',
           direction: :in,
           relationship_class: 'OwnsPetRel'
end
