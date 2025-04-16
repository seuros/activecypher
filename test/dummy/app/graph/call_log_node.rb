# frozen_string_literal: true

class CallLogNode < Neo4jRecord
  attribute :id,          :string
  attribute :callee,      :string
  attribute :duration_s,  :integer
end

# CallLogNode.create(callee: 'John Doe', duration_s: 120)
