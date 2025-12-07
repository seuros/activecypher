# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["Company"]
#
# attributes = [{ name = "id", type = "string" }, { name = "name", type = "string" }, { name = "founding_year", type = "integer" }, { name = "active", type = "boolean" }]
#
# [connection]
# writing = "neo4j"
# reading = "neo4j"
# <rails-lens:graph:end>
class CompanyNode < Neo4jRecord

  attribute :id, :string
  attribute :name, :string
  attribute :founding_year, :integer
  attribute :active, :boolean, default: true

  validates :name, presence: true
end
