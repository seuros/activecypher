# frozen_string_literal: true

module ActiveCypher
  module Model
    # Mixin that gives any graph element (node or edge) an efficient `.count`
    #
    # It issues a single Cypher `COUNT()` query instead of loading rows.
    # Because sometimes you just want to know how many regrets you have, without reliving each one.
    # A little ORM sorcery, a dash of witchcraft, and—very rarely—some back magick make this possible.
    module Countable
      extend ActiveSupport::Concern

      class_methods do
        # @return [Integer] total rows for this label / rel‑type
        # Because loading all the data just to count it is so last decade.
        # If this returns the right number, thank the database gods—or maybe just the back magick hiding in the adapter.
        def count
          cypher, params =
            if respond_to?(:label_name) # ⇒ node class
              if respond_to?(:labels) && labels.any?
                # Use all custom labels for COUNT operations
                label_string = labels.map { |l| ":#{l}" }.join
                ["MATCH (n#{label_string}) RETURN count(n) AS c", {}]
              else
                # Fall back to primary label
                ["MATCH (n:#{label_name}) RETURN count(n) AS c", {}]
              end
            else # ⇒ relationship class
              ["MATCH ()-[r:#{relationship_type}]-() RETURN count(r) AS c", {}] # ▲ undirected
            end

          connection.execute_cypher(cypher, params, 'Count').first[:c].to_i
        end
      end
    end
  end
end
