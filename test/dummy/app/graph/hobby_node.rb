# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["Activity"]
#
# attributes = [{ name = "name", type = "string" }, { name = "category", type = "string" }, { name = "skill_level", type = "string" }]
#
# [associations]
# people = { macro = "has_many", class = "PersonNode", rel = "ENJOYS", direction = "in", relationship_class = "EnjoysRel" }
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
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
