# frozen_string_literal: true

require 'active_model' # ships with Rails 8
require 'active_model/attributes'

module Cyrel
  module Pattern
    class Node
      include ActiveModel::Model
      include ActiveModel::Attributes
      include Cyrel::Parameterizable

      attribute :alias_name, Cyrel::Types::SymbolType.new
      attribute :labels,     array: :string, default: []
      attribute :or_labels,  array: :string, default: []  # Memgraph 3.2+: (n:Label1|Label2)
      attribute :properties, Cyrel::Types::HashType.new, default: -> { {} }

      validates :alias_name, presence: true

      def initialize(alias_name, labels: nil, or_labels: nil, properties: {}, **kw)
        super(
          { alias_name: alias_name,
            labels: Array(labels).compact.flatten,
            or_labels: Array(or_labels).compact.flatten,
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

        # OR labels take precedence (Memgraph 3.2+: n:Label1|Label2)
        if or_labels.any?
          base << ':' << or_labels.join('|')
        elsif labels.any?
          base << ':' << labels.join(':')
        end

        unless properties.empty?
          params = properties.with_indifferent_access
          formatted = params.map do |k, v|
            # Let register_parameter handle loop variable detection
            param_key = query.register_parameter(v)
            if param_key.is_a?(Symbol) && param_key == v
              # Loop variable returned as-is, don't parameterize
              "#{k}: #{v}"
            else
              # Normal parameter key returned
              "#{k}: $#{param_key}"
            end
          end.join(', ')
          base << " {#{formatted}}"
        end
        base << ')'
      end

      def freeze
        super
        labels.freeze
        or_labels.freeze
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
