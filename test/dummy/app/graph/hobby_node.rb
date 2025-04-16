# frozen_string_literal: true

class HobbyNode < ApplicationGraphNode
  attribute :name,        :string
  attribute :category,    :string
  attribute :skill_level, :string

  has_many :people,
           class_name: 'PersonNode',
           relationship: 'ENJOYS',
           direction: :in,
           relationship_class: 'EnjoysRelationship'
end

# HobbyNode.create(name: 'Trolling', category: 'Internet', skill_level: 'Expert')
