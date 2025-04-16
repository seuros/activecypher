# frozen_string_literal: true

class ApplicationGraphRelationship < ActiveCypher::Relationship
  self.abstract_class = true

  connects_to writing: :primary,
              reading: :primary
end
