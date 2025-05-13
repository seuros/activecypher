# frozen_string_literal: true

class DefaultLabelNode < ApplicationGraphNode
  # Uses default label from class name (no explicit label declarations)
  attribute :name, :string
end