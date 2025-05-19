# frozen_string_literal: true

module ActiveCypher
  module Model
    # Destruction: The module that lets you banish records from existence with a single incantation.
    # Uses a blend of Ruby sorcery, a dash of witchcraft, and—on rare occasions—some back magick when nothing else will do.
    module Destruction
      extend ActiveSupport::Concern

      # Deletes the record from the database. Permanently. No takesies-backsies.
      #
      # Runs a Cypher `DETACH DELETE` query on the node.
      # Freezes the object to prevent further use, as a kind of ceremonial burial.
      # Because nothing says "closure" like a frozen Ruby object.
      #
      # @raise [RuntimeError] if the record is new or already destroyed.
      # @return [Boolean] true if the record was successfully destroyed, false if something caught on fire.
      def destroy
        _run(:destroy) do
          raise 'Cannot destroy a new record' if new_record?
          raise 'Record already destroyed' if destroyed?

          n = :n
          labels = self.class.respond_to?(:labels) ? self.class.labels : [self.class.label_name]
          label_string = labels.map { |l| ":#{l}" }.join

          cypher = <<~CYPHER
            MATCH (#{n}#{label_string})
            WHERE id(#{n}) = #{internal_id}
            DETACH DELETE #{n}
            RETURN count(*) AS deleted
          CYPHER

          result = self.class.connection.execute_cypher(cypher, {}, 'Destroy')

          if result.present? && result.first[:deleted].to_i > 0
            @destroyed = true
            freeze
            true
          else
            false
          end
        end
      rescue StandardError => e
        warn "[Destruction] Destroy failed: #{e.class}: #{e.message}"
        false
      end

      # Returns true if this object has achieved full existential closure.
      # If you see this return true and the record still exists, that's not a bug—it's witchcraft.
      def destroyed? = @destroyed == true
    end
  end
end
