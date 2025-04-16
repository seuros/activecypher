# frozen_string_literal: true

require 'active_support/hash_with_indifferent_access'
require 'active_model/type/value'

module Cyrel
  module Types
    class HashType < ActiveModel::Type::Value
      def cast(value)
        case value
        when nil   then ActiveSupport::HashWithIndifferentAccess.new
        when Hash  then value.with_indifferent_access
        else
          value.respond_to?(:to_h) ? value.to_h.with_indifferent_access : {}
        end
      end

      # Serialize as a plain Hash (e.g., for JSON output); symbols are fine
      def serialize(value) = cast(value)
    end
  end
end
