# frozen_string_literal: true

class OwnsPetRelationship < ApplicationGraphRelationship
  from_class 'PersonNode'
  to_class   'PetNode'
  type       'OWNS_PET'

  attribute :adoption_date, :date
  attribute :bond_strength, :integer # Scale of 1–10. You know the pet loves grandma more.
end
