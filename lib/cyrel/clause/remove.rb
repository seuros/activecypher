# frozen_string_literal: true

module Cyrel
  module Clause
    # Represents a REMOVE clause in a Cypher query.
    # Used for removing properties or labels from nodes/relationships.
    class Remove < Base
      attr_reader :items

      # Initializes a REMOVE clause.
      # @param items [Array<Cyrel::Expression::PropertyAccess, Array>]
      #   An array containing items to remove:
      #   - PropertyAccess objects: e.g., Cyrel.prop(:n, :age)
      #   - Label specifications: e.g., [:n, "OldLabel"]
      # @param items [Array<Cyrel::Expression::PropertyAccess, Array>] The items to remove.
      def initialize(items)
        @items = process_items(items) # Remove flatten, expect correct array structure
      end

      # Renders the REMOVE clause.
      # @param query [Cyrel::Query] The query object (used for rendering property access if needed, though unlikely).
      # @return [String, nil] The Cypher string fragment, or nil if no items to remove.
      def render(query)
        return nil if @items.empty?

        remove_parts = @items.map do |item|
          render_item(item, query)
        end

        "REMOVE #{remove_parts.join(', ')}"
      end

      # Merges items from another Remove clause.
      # @param other_remove [Cyrel::Clause::Remove] The other Remove clause to merge.
      def merge!(other_remove)
        # Simple concatenation, assumes no duplicate removals.
        @items.concat(other_remove.items)
        self
      end

      private

      def process_items(items)
        items.map do |item|
          case item
          when Expression::PropertyAccess
            # Remove property: n.prop
            [:property, item]
          when Array
            unless item.length == 2 && item[0].is_a?(Symbol) && item[1].is_a?(String)
              raise ArgumentError, "Invalid label removal format. Expected [:variable, 'Label'], got #{item.inspect}"
            end

            # Remove label: n:Label
            [:label, item[0], item[1]]
          else
            raise ArgumentError, "Invalid item type for REMOVE clause: #{item.class}"
          end
        end
      end

      def render_item(item, query)
        type, target, value = item
        case type
        when :property
          # target is PropertyAccess
          target.render(query) # Renders as "variable.property"
        when :label
          # target is variable symbol, value is label string
          "#{target}:#{value}" # Labels are not parameterized
        end
      end
    end
  end
end
