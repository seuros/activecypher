# frozen_string_literal: true

require 'active_model'

module ActiveCypher
  module Model
    # @!parse
    #   # Core: The module that tries to make your graph model feel like it belongs in a relational world.
    #   # Includes every concern under the sun, because why have one abstraction when you can have twelve?
    #   # Most of this works thanks to a little Ruby sorcery, a dash of witchcraft, and—on rare occasions—some unexplained back magick.
    module Core
      extend ActiveSupport::Concern

      included do
        include ActiveModel::API
        include ActiveModel::Attributes
        include ActiveModel::Dirty
        include ActiveCypher::Associations
        include ActiveCypher::Scoping
        include ActiveModel::Validations

        attribute :internal_id, :string

        cattr_accessor :connection, instance_accessor: false
        class_attribute :configurations, instance_accessor: false,
                                         default: ActiveSupport::HashWithIndifferentAccess.new

        # Add class attribute to store custom labels
        class_attribute :custom_labels, default: Set.new
      end

      class_methods do
        # Define a label for the model. Can be called multiple times to add multiple labels.
        # @param label_name [Symbol, String] The label name
        # @return [Set] The collection of custom labels
        #
        # @example Single label
        #   class PetNode < ApplicationGraphNode
        #     label :Pet
        #   end
        #
        # @example Multiple labels
        #   class PetNode < ApplicationGraphNode
        #     label :Pet
        #     label :Animal
        #   end
        def label(label_name)
          # Convert to symbol for consistency
          label_sym = label_name.to_sym

          # Add to the collection (Set ensures uniqueness)
          self.custom_labels = custom_labels.dup.add(label_sym)
        end

        # Get all labels for this model
        # @return [Array<Symbol>] All labels for this model
        def labels
          # Return custom labels if any exist, otherwise use default label
          custom_labels.empty? ? [model_name.element.to_sym] : custom_labels.to_a
        end

        # Returns the primary label for the model
        # @return [Symbol] The primary label
        def label_name
          # Override the method from Querying module to use the first custom label if any exist
          return custom_labels.first if custom_labels.any?

          # Otherwise fall back to default behavior
          super
        end
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
