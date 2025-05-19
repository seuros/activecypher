# frozen_string_literal: true

class EnjoysRel < ApplicationGraphRelationship
  from_class 'PersonNode'
  to_class   'HobbyNode'
  type       'ENJOYS'

  attribute :frequency,  :string # e.g., "daily", "weekends", "only when crying"
  attribute :since,      :date
end
