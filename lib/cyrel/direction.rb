# frozen_string_literal: true

module Cyrel
  # Simple, Ractor‑shareable direction “enum”.
  module Direction
    OUT  = :outgoing
    IN   = :incoming
    BOTH = :both

    ALL = [OUT, IN, BOTH].freeze

    module_function

    # Checks if a given direction is valid.
    # OUT, IN, or BOTH — just like awkward Tinder DMs.
    def valid?(value) = ALL.include?(value)
  end
end
