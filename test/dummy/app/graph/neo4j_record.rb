# frozen_string_literal: true

class Neo4jRecord < ActiveCypher::Base
  self.abstract_class = true

  connects_to writing: :neo4j,
              reading: :neo4j
end
