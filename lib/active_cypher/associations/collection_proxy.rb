# frozen_string_literal: true

module ActiveCypher
  module Associations
    # @!visibility public
    # CollectionProxy wraps association collections, providing lazy loading and mutation helpers.
    # Because what’s one more layer between you and your data?
    class CollectionProxy < Relation
      attr_reader :owner, :reflection

      # ------------------------------------------------------------
      # construction
      # ------------------------------------------------------------

      # Initializes the proxy, because direct access would be too easy.
      #
      # @param owner [Object] The owning record
      # @param reflection [Hash] The association reflection
      # @param base_relation [Relation] The base relation for the association
      def initialize(owner, reflection, base_relation)
        super(reflection[:class_name].constantize, base_relation.cyrel_query)

        @owner      = owner
        @reflection = reflection
        @records    = nil # lazy – load on first enumeration
      end

      # ------------------------------------------------------------
      # enumeration helpers
      # ------------------------------------------------------------

      # Iterates over the records in the association.
      # Because Rubyists love pretending their database is just an array.
      #
      # @yield [record] Yields each record in the collection
      def each(&)
        load_target unless @records
        @records.each(&)
      end
      alias to_a each

      # Returns the size, because counting things is the only certainty in life.
      #
      # @return [Integer] The number of records in the collection
      def size   = load_target.size
      alias length size

      # Fully refresh from the database.
      # For when you want to relive the disappointment of your data changing.
      #
      # @return [self]
      def reload
        @records = nil
        load_target
        self
      end

      # ------------------------------------------------------------
      # Mutation helpers  ( <<, build, create … )
      # ------------------------------------------------------------

      #
      #   hobby.people << bob
      #
      # * persists the edge (via the relationship model if supplied)
      # * updates the in‑memory collection, so `include?` etc. work
      #
      # Because shoveling objects into a collection is the pinnacle of ORM magic.
      #
      # @param records [Array<Object>] Records to add
      # @return [self]
      def <<(*records)
        unless owner.persisted?
          raise ActiveCypher::PersistenceError,
                'Cannot modify associations on a new record'
        end

        records.flatten.each { |rec| add_record(rec) }
        self
      end

      # Convenient `ids` reader ─ used by a few specs.
      # Because sometimes you just want the IDs and none of the commitment.
      #
      # @return [Array<String>] The internal IDs of the associated records
      def ids
        map(&:internal_id)
      end

      private

      # ------------------------------------------------------------------
      #  helpers
      # ------------------------------------------------------------------

      # Loads the target records, because lazy loading is the only exercise this code gets.
      #
      # @return [Array<Object>] The loaded records
      def load_target
        @records = load_records
      end

      # Adds a record to the association, with all the ceremony of a royal wedding.
      #
      # @param record [Object] The record to add
      # @raise [ArgumentError] if the record is not of the correct class
      # @raise [RuntimeError] if the record is not persisted
      def add_record(record)
        klass = reflection[:class_name].constantize
        raise ArgumentError, "Expected #{klass}, got #{record.class}" unless record.is_a?(klass)
        raise "Associated object #{record.inspect} must be persisted" unless record.persisted?

        # Persist the edge ------------------------------------------------
        rel_klass = reflection[:relationship_class]&.constantize
        dir       = reflection[:direction]

        from_node, to_node =
          case dir
          when :out  then [owner, record]
          when :in   then [record, owner]
          when :both then [owner,  record]
          else raise ArgumentError, "Direction '#{dir}' not supported"
          end

        if rel_klass
          rel_klass.create({}, from_node: from_node, to_node: to_node)
        else
          arrow = (dir == :both ? :'--' : :out)
          Cyrel
            .match(Cyrel.node(from_node.class.label_name).as(:a)
                        .where(Cyrel.node_id(:a).eq(from_node.internal_id)))
            .match(Cyrel.node(to_node.class.label_name).as(:b)
                        .where(Cyrel.node_id(:b).eq(to_node.internal_id)))
            .create(Cyrel.node(:a).rel(arrow, reflection[:relationship]).to(:b))
            .tap { |qry| owner.class.connection.execute_cypher(*qry.to_cypher, 'Create Association') }
        end

        # Keep the in‑memory collection in sync --------------------------
        load_target unless @records # force initial load if needed
        @records << record unless @records.include?(record)
      end
    end
  end
end
