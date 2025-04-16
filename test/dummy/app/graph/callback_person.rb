# frozen_string_literal: true

class CallbackPerson < PersonNode
  attribute :flag, :string

  before_create  ->(rec) { rec.flag = "before"  }
  after_create   ->(rec) { rec.flag = "after"   }
  before_destroy -> { throw(:abort) }
end
