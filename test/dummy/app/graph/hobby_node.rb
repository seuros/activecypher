# frozen_string_literal: true

class HobbyNode < ApplicationGraphNode
  # Define a single custom label
  label :Activity
  attribute :name,        :string
  attribute :category,    :string
  attribute :skill_level, :string

  has_many :people,
           class_name: 'PersonNode',
           relationship: 'ENJOYS',
           direction: :in,
           relationship_class: 'EnjoysRel'
end

# HobbyNode.create(name: 'Trolling', category: 'Internet', skill_level: 'Expert')
