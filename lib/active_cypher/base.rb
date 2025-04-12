# frozen_string_literal: true

require 'active_model'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/hash/keys' # for symbolize_keys

module ActiveCypher
  # Base class for ActiveCypher node models.
  # Includes ActiveModel features for attributes, validations, naming, etc.
  class Base
    # Include common ActiveModel behavior
    include ActiveModel::API
    # Include attribute handling (defines .attribute class method, getters/setters)
    include ActiveModel::Attributes
    # Include dirty tracking
    include ActiveModel::Dirty
    # Include association macros (has_many, belongs_to, etc.)
    include ActiveCypher::Associations
    # Include scoping capabilities
    include ActiveCypher::Scoping
    # NOTE: Consider ActiveModel::Validations, ActiveModel::Callbacks later if needed explicitly.
    # ActiveModel::API includes Naming, Conversion, Validations by default.
    # Define internal attribute for tracking persistence state
    attribute :internal_id, :string # Or appropriate type for DB internal IDs
    # Define internal attribute for primary key if using UUIDs etc.
    # attribute :uuid, :string

    # Stores the connection adapter instance for the current thread or globally.
    # For simplicity initially, we'll use a class attribute.
    # A proper connection pool might be needed for multi-threaded environments.
    # Connection handling
    cattr_accessor :connection, instance_accessor: false

    # Class Methods
    class << self
      # Infers the default graph label name from the model class name.
      # Example: Person -> :Person
      # @return [Symbol] The inferred label name.
      def label_name
        model_name.element.to_sym
      end

      # Finds a record by its internal database identifier or primary key.
      # Placeholder implementation - delegates to adapter.
      # @param id [String, Integer] The identifier of the record to find.
      # @return [ActiveCypher::Base, nil] The found record or nil if not found.
      def find(id)
        node_alias = :n
        # Assuming Cyrel can represent the internal ID function
        # and has methods for equality comparison.
        query = Cyrel.match(Cyrel.node(label_name).as(node_alias))
                     .where(Cyrel.id(node_alias).eq(id)) # Assuming Cyrel.id() represents the id() function
                     .return(node_alias)
                     .limit(1)

        cypher = query.to_cypher # Assumes Cyrel object responds to to_cypher
        # Assuming Cyrel query object can provide parameters if needed,
        # or parameters are embedded in the generated cypher string.
        # params = query.parameters
        params = { id: id } # Simple param binding might still be needed depending on Cyrel

        result = connection.execute_cypher(cypher, params, 'Find')

        # Basic result mapping (can be refined)
        return nil if result.empty?

        node_data = result.first[node_alias] # Assumes result structure [{n: {props...}}]
        node_data ? new(node_data, new_record: false) : nil
      end

      # Creates a new record with the given attributes and saves it.
      # @param attributes [Hash] The attributes for the new record.
      # @return [ActiveCypher::Base] The newly created and saved record.
      # @raise [ValidationError] if the record is invalid (to be implemented).
      def create(attributes = {})
        new(attributes).tap(&:save)
      end
      # --- Querying Methods ---

      # Returns a relation representing all records of this model type,
      # applying the default scope if defined.
      # @return [ActiveCypher::Relation]
      def all
        # Start with a basic relation for this model
        relation = Relation.new(self)

        # Apply default scope if it exists
        if _default_scope
          default_scope_relation = _default_scope.call(self)
          unless default_scope_relation.is_a?(ActiveCypher::Relation)
            raise ArgumentError, 'Default scope body must return an ActiveCypher::Relation.'
          end

          # Merge the default scope conditions into the base relation
          relation = relation.merge(default_scope_relation)
        end

        relation
      end

      # Adds a WHERE condition to the query. Delegates to Relation#where.
      # @param conditions [Hash] Conditions hash.
      # @return [ActiveCypher::Relation]
      def where(conditions)
        all.where(conditions)
      end

      # Adds a LIMIT clause to the query. Delegates to Relation#limit.
      # @param value [Integer] The limit value.
      # @return [ActiveCypher::Relation]
      def limit(value)
        all.limit(value)
      end

      # Adds an ORDER BY clause to the query. Delegates to Relation#order.
      # @param args [Hash, Symbol, String] Ordering criteria.
      # @return [ActiveCypher::Relation]
      def order(*args)
        all.order(*args)
      end

      # --- Connection Handling ---

      # Establishes a connection to the graph database based on the provided configuration.
      #
      # @param config [Hash] Configuration options for the adapter.
      #   Must include an `:adapter` key specifying the adapter name (e.g., `:neo4j`, `:mock`).
      #   Other keys are passed directly to the adapter's initializer (e.g., `:url`, `:username`, `:password`).
      # @return [ActiveCypher::ConnectionAdapters::AbstractAdapter] The established connection adapter instance.
      # @raise [ArgumentError] if the `:adapter` key is missing in the configuration hash.
      # @raise [LoadError] if the specified adapter file cannot be found or loaded.
      # @raise [NameError] if the adapter class (e.g., `ActiveCypher::ConnectionAdapters::MockAdapter`)
      #   cannot be found after loading the file.
      def establish_connection(config)
        config = config.symbolize_keys # Ensure consistent key access
        adapter_name = config[:adapter]
        raise ArgumentError, 'Database configuration must specify an :adapter' unless adapter_name

        adapter_path = "active_cypher/connection_adapters/#{adapter_name}_adapter"
        adapter_class_name = "#{adapter_name}_adapter".camelize

        begin
          # Attempt to load the adapter file. Zeitwerk should handle this if the file
          # exists within its managed directories (like lib/).
          # A manual require might be needed for adapters from external gems if not
          # managed by the application's Zeitwerk instance.
          require adapter_path
        rescue LoadError => e
          # Provide a more informative error message if loading fails.
          raise LoadError, "Could not load the '#{adapter_name}' ActiveCypher adapter. " \
                           'Ensure the adapter name is correct and the corresponding file ' \
                           "(#{adapter_path}.rb) exists. Error: #{e.message}", e.backtrace
        end

        begin
          # Resolve the adapter class constant.
          adapter_class = ActiveCypher::ConnectionAdapters.const_get(adapter_class_name)
        rescue NameError
          raise NameError, "Could not find adapter class '#{adapter_class_name}' within ActiveCypher::ConnectionAdapters. " \
                           "Ensure the class is defined correctly in #{adapter_path}.rb.", caller
        end

        # Instantiate the adapter with the (potentially modified) config hash
        # and store it in the class attribute.
        self.connection = adapter_class.new(config)
        # NOTE: We could optionally call self.connection.connect here to verify
        # the connection immediately, but deferring might be preferable.
        connection
      end
    end

    # Instance Methods

    # Tracks whether the record is newly initialized or loaded from the database.
    attr_reader :new_record

    # Initializes a new instance of the model.
    # @param attributes [Hash] Attributes to assign to the new instance.
    # @param new_record [Boolean] Flag indicating if this is a new record (true) or loaded (false).
    def initialize(attributes = {}, new_record: true)
      super() # Calls ActiveModel::Attributes initializer
      assign_attributes(attributes.symbolize_keys) if attributes
      @new_record = new_record
      # Clear changes from initialization
      clear_changes_information
    end

    # Returns true if the record has not been persisted to the database yet.
    def new_record?
      @new_record
    end

    # Returns true if the record has been persisted to the database.
    def persisted?
      !new_record? && internal_id.present? # Adjust condition based on ID strategy
    end

    # Saves the record to the database (either creates or updates).
    # Placeholder implementation - delegates to private create/update methods.
    # @return [Boolean] true if save was successful, false otherwise.
    def save
      # TODO: Add validation checks (Goal needs refinement or later goal)
      # return false unless valid?
      if new_record?
        create_record
      else
        update_record
      end
      # Assuming success for now
      true
    rescue StandardError # Basic error handling
      # Log error e
      false
    end

    # Updates the record with the given attributes and saves it.
    # @param attributes [Hash] The attributes to update.
    # @return [Boolean] true if update was successful, false otherwise.
    def update(attributes)
      assign_attributes(attributes)
      save
    end

    # Destroys the record in the database using Cyrel.
    # @return [Boolean] true if destroy was successful.
    def destroy
      raise 'Cannot destroy a new record' if new_record?
      raise 'Record already destroyed' if destroyed?

      node_alias = :n
      query = Cyrel.match(Cyrel.node(self.class.label_name).as(node_alias))
                   .where(Cyrel.id(node_alias).eq(internal_id)) # Use internal_id attribute
                   .detach_delete(node_alias) # Assuming detach_delete method

      cypher = query.to_cypher
      # params = query.parameters
      params = { id: internal_id } # Simple param binding might still be needed

      connection.execute_cypher(cypher, params, 'Destroy')
      @destroyed = true
      freeze # Freeze the object after destruction
      true
    rescue StandardError
      # Log error e
      false
    end

    # Returns true if the record has been destroyed.
    def destroyed?
      @destroyed == true
    end

    private

    # Creates a record via the adapter using Cyrel.
    def create_record
      props_to_create = attributes_for_persistence

      node_alias = :n
      # Assuming Cyrel.create takes a node definition with properties
      query = Cyrel.create(Cyrel.node(self.class.label_name, props_to_create).as(node_alias))
                   .return(Cyrel.id(node_alias).as(:internal_id)) # Return the internal ID

      cypher = query.to_cypher
      # params = query.parameters # Or pass props directly if Cyrel handles it
      params = { props: props_to_create }

      result = connection.execute_cypher(cypher, params, 'Create')

      # Assign internal_id from result
      new_id = result.first[:internal_id] # Assumes result structure [{internal_id: ...}]
      self.internal_id = new_id if new_id # Assign if ID is returned

      @new_record = false
      changes_applied # From ActiveModel::Dirty
      true
    end

    # Updates a record via the adapter using Cyrel.
    def update_record
      # Use changes_to_save from ActiveModel::Dirty to get only changed attributes
      props_to_update = changes_to_save

      # Don't run query if nothing changed
      return true if props_to_update.empty?

      node_alias = :n
      # Assuming Cyrel.set takes a hash of properties to update
      query = Cyrel.match(Cyrel.node(self.class.label_name).as(node_alias))
                   .where(Cyrel.id(node_alias).eq(internal_id))
                   .set(node_alias => props_to_update) # Or maybe .set(n: props_to_update)

      cypher = query.to_cypher
      # params = query.parameters # Or pass props directly
      params = { id: internal_id, props: props_to_update }

      connection.execute_cypher(cypher, params, 'Update')
      changes_applied # From ActiveModel::Dirty
      true
    end

    # Helper to get attributes suitable for persistence, excluding internal ID
    # and potentially other non-persistent attributes.
    def attributes_for_persistence
      # Use attribute_names_for_database when available (Rails 7.1+) or fallback
      if defined?(self.class.attribute_names_for_database)
        attributes.slice(*self.class.attribute_names_for_database)
      else
        attributes.except('internal_id') # Basic fallback
      end
    end
  end
end
