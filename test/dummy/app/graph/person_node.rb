# frozen_string_literal: true

class PersonNode < ApplicationGraphNode

  attribute :id, :string
  attribute :name, :string
  attribute :age, :integer
  attribute :active, :boolean, default: true

  validates :name, presence: true
end
