# frozen_string_literal: true

class BelievesInRel < ApplicationGraphRelationship
  from_class 'PersonNode'
  to_class   'ConspiracyNode'
  type       'BELIEVES_IN'

  attribute :reddit_karma_spent, :integer
  attribute :level_of_devotion,  :string # "casual", "zealot", "makes merch"
end
