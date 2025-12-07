# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "relationship"
# type = "OWNS_PET"
# from_class = "PersonNode"
# to_class = "PetNode"
#
# attributes = [{ name = "adoption_date", type = "date" }, { name = "bond_strength", type = "integer" }]
# <rails-lens:graph:end>
class OwnsPetRel < ApplicationGraphRelationship

  from_class 'PersonNode'
  to_class   'PetNode'
  type       'OWNS_PET'

  attribute :adoption_date, :date
  attribute :bond_strength, :integer # Scale of 1–10. You know the pet loves grandma more.
end
