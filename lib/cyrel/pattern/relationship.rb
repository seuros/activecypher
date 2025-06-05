# frozen_string_literal: true

module Cyrel
  module Pattern
    class Relationship
      include ActiveModel::Model
      include ActiveModel::Attributes
      include Cyrel::Parameterizable

      attribute :alias_name, Cyrel::Types::SymbolType.new, default: nil
      attribute :types, array: :string, default: []
      attribute :properties, Cyrel::Types::HashType.new, default: -> { {} }
      attribute :direction,  default: Cyrel::Direction::BOTH
      attribute :length

      def initialize(types:, direction: Cyrel::Direction::BOTH, **kw)
        # Accept string or array for :types just like the old API
        super({ types: Array(types) }.merge(kw).merge(direction: direction))
      end

      def render(query)
        # For anonymous relationships (no alias, no types, no properties, no length)
        # we don't render brackets at all
        if alias_name.nil? && types.empty? && properties.empty? && length.nil?
          case direction
          in Direction::OUT  then '-->'
          in Direction::IN   then '<--'
          else '--'
          end
        else
          # Regular relationship with brackets
          core = +'['
          core << alias_name.to_s if alias_name
          core << ':' << Array(types).join('|') unless types.empty?
          core << length_spec
          core << " #{prop_string(query)}" unless properties.empty?
          core << ']'

          case direction
          in Direction::OUT  then "-#{core}->"
          in Direction::IN   then "<-#{core}-"
          else "-#{core}-"
          end
        end
      end

      private

      # Builds the Cypher length fragment after the relationship type.
      #
      #     *        ➜ variable length (any)
      #     *3       ➜ exact length 3
      #     *1..5    ➜ range 1 – 5
      #     *1..     ➜ open range start (1 or more)
      #     *..5     ➜ open range end   (up to 5)
      def length_spec
        return '' if length.nil?

        case length
        when Integer
          "*#{length}"
        when Range
          start  = length.begin   # nil for ..N ranges
          finish = length.end     # nil for N.. ranges

          "*#{start if start}..#{finish if finish}"
        else
          length # already a string like "*" – keep as‑is
        end
      end

      def prop_string(query)
        formatted = properties.to_h.with_indifferent_access.map do |k, v|
          "#{k}: $#{query.register_parameter(v)}"
        end.join(', ')
        "{#{formatted}}"
      end
    end
  end
end
