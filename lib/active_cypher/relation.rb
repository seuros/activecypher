# frozen_string_literal: true

require 'active_support/core_ext/module/delegation'

module ActiveCypher
  # Chainable, lazily evaluated Cypher query.
  # Because what you really want is to pretend your database is just a big Ruby array.
  class Relation
    include Enumerable

    attr_reader :model_class, :cyrel_query

    # Methods that trigger query execution
    # Because nothing says "performance" like loading everything at once.
    LOAD_METHODS = %i[each to_a first last count size length any? empty?].freeze

    # ------------------------------------------------------------------
    # Construction
    # ------------------------------------------------------------------
    # Initializes a Relation. Because direct SQL was too mainstream.
    # @param model_class [Class] The model class for the relation
    # @param cyrel_query [Object, nil] The Cyrel query object
    def initialize(model_class, cyrel_query = nil)
      @model_class = model_class
      @cyrel_query = cyrel_query || default_query
      @records     = nil
    end

    # ------------------------------------------------------------------
    # Query‑builder helpers
    # ------------------------------------------------------------------
    # Because chaining methods is more fun than writing actual queries.
    # @param conditions [Hash, Cyrel::Expression::Base] The conditions for the where clause
    # @return [Relation] A new relation with the where clause applied
    def where(conditions)
      new_query = @cyrel_query.clone
      node_alias = :n

      case conditions
      when Hash
        conditions.each do |key, value|
          expr      = Cyrel.prop(node_alias, key).eq(value)
          new_query = new_query.where(expr)
        end
      when Cyrel::Expression::Base
        new_query = new_query.where(conditions)
      else
        raise ArgumentError,
              "Unsupported type for #where: #{conditions.class}. " \
              'Pass a Hash or Cyrel::Expression.'
      end

      spawn(new_query)
    end

    # Because sometimes you want less data, but never less abstraction.
    # @param value [Integer] The limit value
    # @return [Relation]
    def limit(value)
      spawn(@cyrel_query.clone.limit(value))
    end

    # ORDER support: coming soon, like your next vacation.
    # @return [Relation]
    def order(*_args)
      # TODO: Implement proper ORDER support
      spawn(@cyrel_query)
    end

    # Merges another relation, because why not double the confusion.
    # @param _other [Relation]
    # @return [Relation]
    def merge(_other)
      spawn(@cyrel_query.clone)
    end

    # ------------------------------------------------------------------
    # Enumerable / loader
    # ------------------------------------------------------------------
    # Pretend this is just an array. Your database will never know.
    # @yield [record] Yields each record in the relation
    def each(&)
      load_records unless loaded?
      @records.each(&)
    end

    # Because everyone wants to be first.
    # @return [Object, nil] The first record
    def first
      load_records unless loaded?
      @records.first
    end

    # Or last, if you're feeling dramatic.
    # @return [Object, nil] The last record
    def last
      load_records unless loaded?
      @records.last
    end

    # Counting records: the only math most devs trust.
    # @return [Integer] The number of records
    def count
      load_records unless loaded?
      @records.count
    end
    alias size   count
    alias length count

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    # Checks if we've already loaded the records, or if we're still living in denial.
    # @return [Boolean]
    def loaded?
      !@records.nil?
    end

    # Resets the loaded records, for when you want to pretend nothing ever happened.
    # @return [void]
    def reset!
      @records = nil
    end

    private

    # Default: MATCH (n:Label) RETURN n, elementId(n) AS internal_id
    # Because writing Cypher by hand is for people with too much free time.
    # @return [Object] The default Cyrel query
    def default_query
      node_alias = :n

      # Use all labels if available, otherwise fall back to primary label
      labels = if model_class.respond_to?(:labels)
                 model_class.labels
               elsif model_class.respond_to?(:label_name)
                 [model_class.label_name]
               else
                 [model_class.model_name.element.to_sym]
               end

      Cyrel
        .match(Cyrel.node(node_alias, *labels))
        .return_(node_alias, Cyrel.node_id(node_alias).as(:internal_id))
    end

    # Actually loads the records from the database, shattering the illusion of laziness.
    # @return [void]
    def load_records
      cypher, params = @cyrel_query.to_cypher
      raw            = model_class.connection.execute_cypher(
        cypher, params || {}, 'Load Relation'
      )
      @records = map_results(raw)
    end

    # Maps raw database results into something you can almost believe is a real object.
    # @param raw_results [Array<Hash, Array>] The raw results from the database
    # @return [Array<Object>] The mapped records
    def map_results(raw_results)
      raw_results.map do |row|
        # ------------------------------------------------------------
        # 1. Pull out the node payload and the elementId string
        # ------------------------------------------------------------
        if row.is_a?(Hash)
          node_payload = row[:n] || row['n'] || row
          element_id   = row[:internal_id] || row['internal_id']
        else # Array row: [node, id]
          node_payload, element_id = row
        end

        # ------------------------------------------------------------
        # 2. If the node is still in Bolt array form [78, [...]],
        #    convert it to { "name"=>"Bob", ... }
        # ------------------------------------------------------------
        if node_payload.is_a?(Array) && node_payload.first == 78
          # Re‑use the adapter's private helper for consistency
          node_payload = model_class.connection
                                    .send(:process_node, node_payload)
        end

        # Now we have a plain hash of properties
        attrs = node_payload.with_indifferent_access
        attrs[:internal_id] = element_id if element_id
        # Use instantiate instead of new to mark records as persisted
        model_class.instantiate(attrs)
      end
    end

    # Spawns a new Relation, because immutability is trendy.
    # @param new_query [Object] The new Cyrel query
    # @return [Relation]
    def spawn(new_query)
      self.class.new(@model_class, new_query)
    end
  end
end
