# frozen_string_literal: true

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
           relationship_class: 'OwnsPetRelationship'
end
