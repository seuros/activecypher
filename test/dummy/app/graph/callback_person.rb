# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["CallbackPerson"]
#
# attributes = [{ name = "id", type = "string" }, { name = "name", type = "string" }, { name = "age", type = "integer" }, { name = "active", type = "boolean" }, { name = "flag", type = "string" }]
#
# [associations]
# hobbies = { macro = "has_many", class = "HobbyNode", rel = "ENJOYS", relationship_class = "EnjoysRel" }
#
# [connection]
# writing = "primary"
# reading = "primary"
# <rails-lens:graph:end>
class CallbackPerson < PersonNode

  attribute :flag, :string

  before_create  ->(rec) { rec.flag = "before"  }
  after_create   ->(rec) { rec.flag = "after"   }
  before_destroy -> { throw(:abort) }
end
