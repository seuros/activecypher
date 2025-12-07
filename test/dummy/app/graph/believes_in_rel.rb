# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "relationship"
# type = "BELIEVES_IN"
# from_class = "PersonNode"
# to_class = "ConspiracyNode"
#
# attributes = [{ name = "reddit_karma_spent", type = "integer" }, { name = "level_of_devotion", type = "string" }]
# <rails-lens:graph:end>
class BelievesInRel < ApplicationGraphRelationship

  from_class 'PersonNode'
  to_class   'ConspiracyNode'
  type       'BELIEVES_IN'

  attribute :reddit_karma_spent, :integer
  attribute :level_of_devotion,  :string # "casual", "zealot", "makes merch"
end
