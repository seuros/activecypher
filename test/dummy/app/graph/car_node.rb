# frozen_string_literal: true

class CarNode < ApplicationGraphNode
  # Define a single custom label
  label :Vehicle

  attribute :make, :string
  attribute :model, :string
end