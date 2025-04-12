# frozen_string_literal: true

require 'active_support/core_ext/module/delegation'
require 'cyrel' # Assuming cyrel is available

module ActiveCypher
  # Represents a chainable, lazily evaluated Cypher query.
  # Instances are typically created by calling query methods on ActiveCypher::Base subclasses.
  class Relation
    include Enumerable

    attr_reader :model_class, :cyrel_query

    # Methods that trigger query execution when called on a Relation
    LOAD_METHODS = %i[each to_a first last count size length any? empty?].freeze

    # @param model_class [Class < ActiveCypher::Base] The model class this relation queries.
    # @param cyrel_query [Cyrel::Query] The underlying Cyrel query object being built.
    def initialize(model_class, cyrel_query = nil)
      @model_class = model_class
      # Initialize a basic Cyrel query if none is provided
      # This assumes Cyrel has a way to start a query targeting a node type
      @cyrel_query = cyrel_query || Cyrel.match(Cyrel.node(model_class.label_name).as(:n)).return(:n)
      @records = nil # Cache for loaded records
    end

    # --- Query Building Methods ---

    # Adds a WHERE condition.
    # Currently supports basic hash conditions (equality).
    # @param conditions [Hash] Conditions hash (e.g., { name: 'Alice', age: 30 }).
    # @return [ActiveCypher::Relation] A new relation with the added condition.
    def where(conditions)
      # TODO: Integrate with Cyrel's WHERE clause building
      new_query = @cyrel_query # Placeholder
      conditions.each do |key, value|
        # Example Cyrel integration (adjust based on actual Cyrel API)
        # node_alias = @cyrel_query.root_node_alias || :n # Need a way to get the main node alias
        # new_query = new_query.where(Cyrel.node(node_alias)[key].eq(value))
      end
      spawn(new_query)
    end

    # Adds a LIMIT clause.
    # @param value [Integer] The maximum number of records to return.
    # @return [ActiveCypher::Relation] A new relation with the limit applied.
    def limit(_value)
      # TODO: Integrate with Cyrel's LIMIT clause building
      new_query = @cyrel_query # Placeholder
      # Example Cyrel integration: new_query = new_query.limit(value)
      spawn(new_query)
    end

    # Adds an ORDER BY clause.
    # @param args [Hash, Symbol, String] Ordering criteria (e.g., :name, { age: :desc }).
    # @return [ActiveCypher::Relation] A new relation with the ordering applied.
    def order(*_args)
      # TODO: Integrate with Cyrel's ORDER BY clause building
      new_query = @cyrel_query # Placeholder
      # Example Cyrel integration: new_query = new_query.order(...)
      spawn(new_query)
    end

    # Merges the conditions from another Relation or scope into this one.
    # Placeholder implementation. Needs actual Cyrel query merging logic.
    # @param other [ActiveCypher::Relation, Hash] The relation or conditions to merge.
    # @return [ActiveCypher::Relation] A new relation with merged conditions.
    def merge(_other)
      # TODO: Implement merging of Cyrel query objects.
      # This needs to combine WHERE clauses, potentially LIMIT, ORDER etc.
      # For now, just return a clone of the current relation's query.
      spawn(@cyrel_query.clone) # Placeholder
    end

    # --- Query Execution Methods ---

    # Executes the query and yields each resulting model instance.
    # Implements the Enumerable interface.
    def each(&block)
      load_records unless loaded?
      @records.each(&block)
    end

    # Returns the first record matching the query.
    # @return [ActiveCypher::Base, nil] The first record or nil.
    def first
      # TODO: Optimize by adding LIMIT 1 to Cyrel query before execution
      load_records unless loaded?
      @records.first
    end

    # Returns the last record matching the query.
    # Requires ordering to be meaningful.
    # @return [ActiveCypher::Base, nil] The last record or nil.
    def last
      # TODO: Optimize? Might require reversing order and taking first.
      load_records unless loaded?
      @records.last
    end

    # Returns the count of records matching the query.
    # @return [Integer] The count.
    def count
      # TODO: Optimize by changing Cyrel query to RETURN count(*)
      load_records unless loaded?
      @records.count
    end
    alias size count
    alias length count

    # --- Internal Methods ---

    # Returns true if the records for this relation have been loaded.
    def loaded?
      !@records.nil?
    end

    # Resets the loaded records cache.
    def reset!
      @records = nil
    end

    private

    # Executes the Cyrel query via the adapter and maps results to model instances.
    def load_records
      cypher_string = @cyrel_query.to_cypher # Assumes Cyrel has a to_cypher method
      params = {} # TODO: Extract params from Cyrel query if needed
      raw_results = model_class.connection.execute_cypher(cypher_string, params, 'Load Relation')

      # Map raw results (assuming adapter returns array of hashes)
      @records = map_results(raw_results)
    rescue StandardError => e
      # Log error
      @records = [] # Avoid repeated errors
      raise e
    end

    # Maps raw database results to model instances.
    # @param raw_results [Array] Array of result hashes from the adapter.
    # @return [Array<ActiveCypher::Base>] Array of model instances.
    def map_results(raw_results)
      # This assumes the query returns the node data under the alias used (e.g., :n)
      # and the adapter returns hashes representing node properties.
      node_alias = :n # TODO: Get this dynamically from @cyrel_query if possible
      raw_results.map do |result_hash|
        node_data = result_hash[node_alias]
        # Instantiate the model, marking it as not a new record
        model_class.new(node_data || {}, new_record: false) if node_data
      end.compact
    end

    # Creates a new Relation instance based on the current one,
    # but with a modified Cyrel query. Used by query-building methods.
    # @param new_query [Cyrel::Query] The modified Cyrel query.
    # @return [ActiveCypher::Relation] The new relation instance.
    def spawn(new_query)
      self.class.new(@model_class, new_query)
    end
  end
end
