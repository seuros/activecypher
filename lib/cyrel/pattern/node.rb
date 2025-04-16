# frozen_string_literal: true

require 'active_model' # ships with Rails 8
require 'active_model/attributes'

module Cyrel
  module Pattern
    class Node
      include ActiveModel::Model
      include ActiveModel::Attributes # :contentReference[oaicite:3]{index=3}
      include Cyrel::Parameterizable

      attribute :alias_name, Cyrel::Types::SymbolType.new
      attribute :labels,     array: :string, default: []
      attribute :properties, Cyrel::Types::HashType.new, default: -> { {} }

      validates :alias_name, presence: true

      def initialize(alias_name, labels: nil, properties: {}, **kw)
        super(
          { alias_name: alias_name,
            labels: Array(labels).compact.flatten,
            properties: properties }.merge(kw)
        )
      end

      # ------------------------------------------------------------------
      # Public: return a *copy* of this Node with a different alias.
      #
      #   Cyrel.node('Person').as(:p)      # (:p:Person)
      #
      # We dup so the original immutable instance (often reused by the DSL)
      # isn’t mutated.
      # ------------------------------------------------------------------
      def as(new_alias)
        dup_with(alias_name: new_alias.to_sym)
      end

      def render(query)
        base = +"(#{alias_name}"
        base << ':' << labels.join(':') unless labels.empty?
        unless properties.empty?
          params = properties.with_indifferent_access
          formatted = params.map { |k, v| "#{k}: $#{query.register_parameter(v)}" }.join(', ')
          base << " {#{formatted}}"
        end
        base << ')'
      end

      def freeze
        super
        labels.freeze
        properties.freeze
      end

      private

      # Utility used by Node & Relationship to make modified copies
      def dup_with(**attrs)
        copy = dup
        attrs.each { |k, v| copy.public_send("#{k}=", v) }
        copy
      end
    end
  end
end
