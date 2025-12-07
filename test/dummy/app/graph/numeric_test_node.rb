# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["NumericTest"]
#
# attributes = [{ name = "integer_value", type = "integer" }, { name = "float_value", type = "float" }, { name = "decimal_value", type = "decimal" }, { name = "name", type = "string" }]
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class NumericTestNode < ApplicationGraphNode

  attribute :integer_value, :integer
  attribute :float_value, :float
  attribute :decimal_value, :decimal
  attribute :name, :string

  validates :name, presence: true
end