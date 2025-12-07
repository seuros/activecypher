# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["FirstLabel", "SecondLabel", "ThirdLabel"]
#
# attributes = [{ name = "name", type = "string" }, { name = "description", type = "string" }, { name = "level", type = "integer" }]
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class MultiLabelTheoryNode < ApplicationGraphNode

  # Define three labels for testing multiple labels
  label :FirstLabel
  label :SecondLabel
  label :ThirdLabel

  attribute :name, :string
  attribute :description, :string
  attribute :level, :integer
end