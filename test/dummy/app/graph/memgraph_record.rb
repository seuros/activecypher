# frozen_string_literal: true

class MemgraphRecord < ActiveCypher::Base
  self.abstract_class = true

  connects_to writing: :primary
end
