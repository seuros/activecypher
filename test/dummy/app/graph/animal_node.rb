# frozen_string_literal: true

class AnimalNode < ApplicationGraphNode
  # Define multiple labels
  label :Animal
  label :LivingBeing
  
  attribute :name, :string
  attribute :species, :string
end