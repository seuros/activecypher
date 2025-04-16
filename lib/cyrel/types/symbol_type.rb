# frozen_string_literal: true

module Cyrel
  module Types
    # inherits low‑overhead base
    class SymbolType < ActiveModel::Type::Value
      # String/ Symbol → Symbol / nil
      def cast(value) = value&.to_sym
      # Symbol → String (for JSON, etc.)
      def serialize(value) = value.to_s
    end
  end
end
