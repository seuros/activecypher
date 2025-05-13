# frozen_string_literal: true

class MultiLabelTheoryNode < ApplicationGraphNode
  # Define three labels for testing multiple labels
  label :FirstLabel
  label :SecondLabel
  label :ThirdLabel
  
  attribute :name, :string
  attribute :description, :string
  attribute :level, :integer
end