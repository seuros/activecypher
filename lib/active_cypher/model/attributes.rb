# frozen_string_literal: true

module ActiveCypher
  module Model
    # @!parse
    #   # Attributes: Because every model needs a place to store its baggage.
    #   # Provides helpers for attribute persistence, so you can pretend your data is tidy.
    #   # Also, because every good ORM needs a little bit of witchcraft to make things “just work.”
    #   # If you see something working and can't explain why, it's probably quantum Ruby entanglement.
    module Attributes
      extend ActiveSupport::Concern

      # Helpers
      private

      # Returns the attributes to be persisted, minus the internal_id.
      # Because sometimes you just want to forget where you came from.
      # @return [Hash] The attributes suitable for persistence
      def attributes_for_persistence
        attributes.except('internal_id').compact
      end
    end
  end
end
