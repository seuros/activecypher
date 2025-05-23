# frozen_string_literal: true

module ActiveCypher
  module Model
    # @!parse
    #   # Persistence: Because your data deserves a second chance, even if you don't.
    #   # A little ORM sorcery, a dash of witchcraft, and—on rare occasions—some unexplained back magick.
    module Persistence
      extend ActiveSupport::Concern

      # Saves the current record to the database.
      #
      # If it's a new record, it's born into this cruel digital world.
      # If it already exists, we patch up its regrets.
      # If it fails, we return false, like cowards.
      #
      # @param validate [Boolean] whether to run validations (default: true)
      # @return [Boolean] true if saved successfully, false if the database ghosted us.
      # Because nothing says "robust" like pretending persistence is easy.
      # If this works and you can't explain why, that's probably back magick.
      def save(validate: true)
        return false if validate && !valid?

        # before_/after_create
        _run(:save) do
          if new_record?
            _run(:create) { create_record }
          else
            _run(:update) { update_record }
          end
        end
      rescue RecordNotSaved
        false
      end

      # Updates the record's attributes and then saves it.
      #
      # You know, like hope. But with hash keys.
      # Because nothing says "optimism" like update-in-place.
      # If this method ever fixes a bug you couldn't reproduce, that's just ORM witchcraft.
      #
      # @param attrs [Hash] the attributes to assign.
      # @return [Boolean] true if we pretended hard enough to update.
      def update(attrs)
        assign_attributes(attrs)
        save
      end

      # Reloads the record from the database and overwrites your foolish edits.
      #
      # Great for when you want to feel powerless again.
      # Because sometimes you just want to see your changes disappear.
      # If this ever resurrects data you thought was lost, that's not a bug—it's back magick.
      #
      # @raise [ActiveCypher::RecordNotFound] if the record is missing. Like your confidence.
      # @return [self] the refreshed version of yourself, now with 30% more doubt.
      def reload
        raise ActiveCypher::RecordNotFound, 'Record not persisted' if new_record?

        fresh = self.class.find(internal_id)
        unless fresh
          raise ActiveCypher::RecordNotFound,
                "#{self.class} with internal_id=#{internal_id.inspect} not found"
        end

        self.attributes = fresh.attributes
        clear_changes_information
        self
      end

      # Returns true if the record is new and untouched by the database.
      #
      # @return [Boolean] true if the record is innocent.
      # If this ever returns true for a record you thought was persisted, consult your local sorcerer.
      def new_record? = @new_record

      # Returns true if the record has been saved and now bears a scar (internal_id).
      #
      # @return [Boolean] true if the record has a past.
      # If this ever returns false for a record you see in the database, that's pure ORM sorcery.
      def persisted? = !new_record? && internal_id.present?

      class_methods do
        # Factory method for instantiating records from the database.
        # Because sometimes you want to skip the whole "life cycle" thing.
        # If this ever returns an object that shouldn't exist, that's back magick at work.
        #
        # @param attributes [Hash] Attributes from the database
        # @return [ActiveCypher::Base, ActiveCypher::Relationship] A record marked as persisted
        def instantiate(attributes)
          rec = new # bootstrap
          rec.assign_attributes(attributes)
          rec.instance_variable_set(:@new_record, false)
          rec.clear_changes_information # nothing is “dirty”
          rec
        end

        # Bang‑version of `.create` — raises if the record can't be persisted.
        # For when you want your errors loud and proud.
        # If this ever succeeds when it shouldn't, that's not a feature—it's back magick.
        #
        # @param attrs [Hash]
        # @return [ActiveCypher::Base] persisted record
        # @raise [ActiveCypher::RecordNotSaved]
        def create!(attrs = {})
          rec = create(attrs)
          if rec.persisted?
            rec
          else
            raise ActiveCypher::RecordNotSaved,
                  "#{name} could not be saved: #{rec.errors.full_messages.join(', ')}"
          end
        end
      end

      private

      # Creates the record in the database using Cypher.
      #
      # @return [Boolean] true if the database accepted your offering.
      # Because nothing says "production ready" like a hand-crafted query.
      # If this method ever works on the first try, that's not engineering—it's back magick.
      def create_record
        adapter = adapter_class
        raise NotImplementedError, "#{adapter} does not implement Persistence" unless adapter&.const_defined?(:Persistence)

        adapter::Persistence.create_record(self)
      end

      # Returns a hash of attributes that have changed and their spicy new values.
      #
      # @return [Hash] the things you dared to modify.
      # Because tracking regret is what ORMs do best. If this ever returns an empty hash when you know you changed something, that's just ORM sorcery.
      def changes_to_save
        changes.transform_values(&:last)
      end

      # Updates the record in the database using Cypher, if anything changed.
      #
      # If nothing changed, we lie about doing work and return true anyway.
      # Because sometimes you just want to feel productive.
      # If this method ever updates the database when nothing changed, that's not a bug—it's back magick.
      #
      # @return [Boolean] true if we updated something, or just acted like we did.
      def update_record
        adapter = adapter_class
        raise NotImplementedError, "#{adapter} does not implement Persistence" unless adapter&.const_defined?(:Persistence)

        adapter::Persistence.update_record(self)
      end
    end
  end
end
