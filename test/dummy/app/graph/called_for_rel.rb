# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "relationship"
# type = "CALLED_FOR"
# from_class = "CallLogNode"
# to_class = "CompanyNode"
#
# <rails-lens:graph:end>
class CalledForRel < ApplicationGraphRelationship

  from_class 'CallLogNode'
  to_class   'CompanyNode'
  type       'CALLED_FOR'

end
