# frozen_string_literal: true

module ActiveCypher
  module Model
    module Labelling
      extend ActiveSupport::Concern

      included do
        # Use array instead of set to preserve insertion order of labels
        class_attribute :custom_labels, default: []
      end

      class_methods do
        # Define a label for the model. Can be called multiple times to add multiple labels.
        # @param label_name [Symbol, String] The label name
        # @return [Array] The collection of custom labels
        def label(label_name)
          label_sym = label_name.to_sym
          self.custom_labels = custom_labels.dup << label_sym unless custom_labels.include?(label_sym)
          custom_labels
        end

        # Get all labels for this model
        # @return [Array<Symbol>] All labels for this model
        def labels
          custom_labels.empty? ? [default_label] : custom_labels
        end

        # Returns the primary label for the model
        # @return [Symbol] The primary label
        def label_name
          custom_labels.any? ? custom_labels.first : default_label
        end

        # Computes the default label for the model based on class name
        # Strips 'Node' or 'Record' suffix, returns as symbol, capitalized
        def default_label
          base = name.split('::').last
          base = base.sub(/(Node|Record)\z/, '')
          base.to_sym
        end
      end
    end
  end
end
