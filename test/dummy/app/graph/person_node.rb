# frozen_string_literal: true

class PersonNode < ApplicationGraphNode

  attribute :id, :string
  attribute :name, :string
  attribute :age, :integer
  attribute :active, :boolean, default: true
  attribute :internal_id, :string

  validates :name, presence: true
end
