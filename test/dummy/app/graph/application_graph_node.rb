# frozen_string_literal: true

class ApplicationGraphNode < ActiveCypher::Base
  self.abstract_class = true

  connects_to writing: :primary
end
