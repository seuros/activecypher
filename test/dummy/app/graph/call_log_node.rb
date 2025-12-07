# frozen_string_literal: true

# <rails-lens:graph:begin>
# model_type = "node"
# labels = ["CallLog"]
#
# attributes = [{ name = "id", type = "string" }, { name = "callee", type = "string" }, { name = "duration_s", type = "integer" }]
#
# [connection]
# writing = "neo4j"
# reading = "neo4j"
# <rails-lens:graph:end>
class CallLogNode < Neo4jRecord

  attribute :id,          :string
  attribute :callee,      :string
  attribute :duration_s,  :integer
end

# CallLogNode.create(callee: 'John Doe', duration_s: 120)
