# frozen_string_literal: true

module ActiveCypher
  module Model
    # Core: The module that tries to make your graph model feel like it belongs in a relational world.
    # Includes every concern under the sun, because why have one abstraction when you can have twelve?
    # Most of this works thanks to a little Ruby sorcery, a dash of witchcraft, and—on rare occasions—some unexplained back magick.
    module Core
      extend ActiveSupport::Concern

      included do
        include ActiveCypher::Associations
        include ActiveCypher::Scoping

        attribute :internal_id, :integer

        class_attribute :configurations, instance_accessor: false,
                                         default: ActiveSupport::HashWithIndifferentAccess.new
      end

      attr_reader :new_record

      # Initializes a new model instance, because every object deserves a fresh start (and a fresh set of existential crises).
      #
      # @param attributes [Hash] Attributes to assign to the new instance
      # @note If this works and you can't explain why, it's probably back magick.
      def initialize(attributes = {})
        _run(:initialize) do # <-- callback wrapper
          super()
          assign_attributes(attributes.symbolize_keys) if attributes
          @new_record = true # Always true for normal initialization, because innocence is fleeting
          clear_changes_information
        end
      end
    end
  end
end
