# frozen_string_literal: true

class ApplicationGraphNode < ActiveCypher::Base
  # Adapter‑specific helpers are injected after connection
  connects_to writing: :primary
end
