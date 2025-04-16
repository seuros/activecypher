# frozen_string_literal: true

class CompanyNode < Neo4jRecord
  attribute :id, :string
  attribute :name, :string
  attribute :founding_year, :integer
  attribute :active, :boolean, default: true
  attribute :internal_id, :string

  validates :name, presence: true
end
