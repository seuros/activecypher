# frozen_string_literal: true

module ActiveCypher
  module Model
    # @!parse
    #   # Destruction: The module that lets you banish records from existence with a single incantation.
    #   # Uses a blend of Ruby sorcery, a dash of witchcraft, and—on rare occasions—some back magick when nothing else will do.
    module Destruction
      extend ActiveSupport::Concern

      # Deletes the record from the database. Permanently. No takesies-backsies.
      #
      # Runs a Cypher `DETACH DELETE` query on the node.
      # Freezes the object to prevent further use, as a kind of ceremonial burial.
      # Because nothing says "closure" like a frozen Ruby object.
      # If this works and you can't explain why, that's probably back magick.
      #
      # @raise [RuntimeError] if the record is new or already destroyed.
      # @return [Boolean] true if the record was successfully destroyed, false if something caught on fire.
      def destroy
        _run(:destroy) do
          raise 'Cannot destroy a new record' if new_record?
          raise 'Record already destroyed' if destroyed?

          n      = :n
          query  = Cyrel.match(Cyrel.node(self.class.label_name).as(n))
                        .where(Cyrel.id(n).eq(internal_id))
                        .detach_delete(n)

          cypher = query.to_cypher
          params = { id: internal_id }

          # Here lies the true sorcery: one line to erase a node from existence.
          # If the database still remembers it, you may need to consult your local witch.
          self.class.connection.execute_cypher(cypher, params, 'Destroy')
          @destroyed = true
          freeze # To make sure you can't Frankenstein it back to life. Lightning not included.
          true
        end
      rescue StandardError
        false # Something went wrong. Don’t ask. Just walk away. Or blame the database, that's always fun. If it keeps happening, suspect back magick.
      end

      # Returns true if this object has achieved full existential closure.
      # If you see this return true and the record still exists, that's not a bug—it's witchcraft.
      def destroyed? = @destroyed == true
    end
  end
end
