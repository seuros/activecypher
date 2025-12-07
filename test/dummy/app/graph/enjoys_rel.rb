# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "relationship"
# type = "ENJOYS"
# from_class = "PersonNode"
# to_class = "HobbyNode"
#
# attributes = [{ name = "frequency", type = "string" }, { name = "since", type = "date" }]
# <rails-lens:graph:end>
class EnjoysRel < ApplicationGraphRelationship

  from_class 'PersonNode'
  to_class   'HobbyNode'
  type       'ENJOYS'

  attribute :frequency,  :string # e.g., "daily", "weekends", "only when crying"
  attribute :since,      :date
end
