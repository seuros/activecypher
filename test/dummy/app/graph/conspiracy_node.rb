# frozen_string_literal: true

class ConspiracyNode < ApplicationGraphNode
  # Define multiple labels
  label :Conspiracy
  label :Theory

  attribute :name,         :string
  attribute :description,  :string
  attribute :believability_index, :integer # From 0 (flat earth) to 10 (birds aren't real)

  has_many :followers,
           class_name: 'PersonNode',
           relationship: 'BELIEVES_IN',
           direction: :in,
           relationship_class: 'BelievesInRel'
end
