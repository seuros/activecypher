# frozen_string_literal: true

require 'active_model'
require 'active_support/core_ext/class/attribute'

module ActiveCypher
  # Base class for ActiveCypher relationship models.
  # Represents graph edges, potentially with properties.
  class Relationship
    # Include common ActiveModel behavior
    include ActiveModel::API
    # Include attribute handling for relationship properties
    include ActiveModel::Attributes
    # Include dirty tracking for relationship properties
    include ActiveModel::Dirty
    # Include Naming for model_name introspection
    include ActiveModel::Naming

    # Define internal attribute for tracking persistence state (relationship ID)
    attribute :internal_id, :string # Or appropriate type for DB internal IDs

    # Class attributes to store relationship definition
    class_attribute :_from_class_name, instance_writer: false
    class_attribute :_to_class_name, instance_writer: false
    class_attribute :_relationship_type, instance_writer: false

    # References to the connected node objects
    attr_accessor :from_node, :to_node

    # Class Methods
    class << self
      # Sets the class name of the source node for this relationship type.
      # @param class_name [String, Symbol, Class] The class name (e.g., "Person", :Person, Person).
      def from_class(class_name)
        self._from_class_name = class_name.to_s
      end

      # Sets the class name of the target node for this relationship type.
      # @param class_name [String, Symbol, Class] The class name (e.g., "Company", :Company, Company).
      def to_class(class_name)
        self._to_class_name = class_name.to_s
      end

      # Sets the underlying graph relationship type (e.g., "WORKS_AT").
      # @param type_name [String, Symbol] The relationship type name.
      def type(type_name)
        self._relationship_type = type_name.to_s.upcase
      end

      # Placeholder for finding relationships (might be complex)
      # def find(...)
      # end

      # Placeholder for creating relationships
      # def create(attributes = {})
      #   new(attributes).tap(&:save)
      # end

      # Provides access to the connection adapter (inherited from Base or set globally)
      # TODO: Refine connection access if Relationship doesn't inherit Base's connection directly
      def connection
        ActiveCypher::Base.connection
      end
    end

    # Instance Methods

    # Tracks whether the relationship is newly initialized or loaded.
    attr_reader :new_record

    # Initializes a new instance of the relationship model.
    # @param attributes [Hash] Attributes (properties) for the relationship.
    # @param from_node [ActiveCypher::Base] The source node instance.
    # @param to_node [ActiveCypher::Base] The target node instance.
    # @param new_record [Boolean] Flag indicating if this is new or loaded.
    def initialize(attributes = {}, from_node: nil, to_node: nil, new_record: true)
      super() # Calls ActiveModel::Attributes initializer
      assign_attributes(attributes.symbolize_keys) if attributes
      @from_node = from_node
      @to_node = to_node
      @new_record = new_record
      clear_changes_information
    end

    # Returns true if the relationship has not been persisted yet.
    def new_record?
      @new_record
    end

    # Returns true if the relationship has been persisted.
    def persisted?
      !new_record? && internal_id.present?
    end

    # Saves the relationship to the database (creates it).
    # Updating relationships might require different logic (finding by ID first).
    # @return [Boolean] true if save was successful.
    def save
      raise 'Cannot save relationship without both from_node and to_node' unless from_node && to_node

      # TODO: Add validation checks
      # return false unless valid?

      if new_record?
        create_relationship
      else
        # TODO: Implement update logic if needed (updating relationship properties)
        update_relationship
      end
      true
    rescue StandardError
      # Log error e
      false
    end

    # Destroys the relationship in the database.
    # @return [Boolean] true if destroy was successful.
    def destroy
      raise 'Cannot destroy a new relationship' if new_record?
      raise 'Relationship already destroyed' if destroyed?

      # TODO: Implement Cyrel query generation
      # Need to match the relationship based on its internal_id or potentially
      # by matching the connected nodes and relationship type/properties.
      # Example using internal_id:
      # query = Cyrel.match(...).where(Cyrel.id(rel_alias).eq(internal_id)).delete(rel_alias)
      cypher = 'MATCH ()-[r]-() WHERE id(r) = $id DELETE r' # Placeholder
      params = { id: internal_id }

      self.class.connection.execute_cypher(cypher, params, 'Destroy Relationship')
      @destroyed = true
      freeze
      true
    rescue StandardError
      # Log error e
      false
    end

    def destroyed?
      @destroyed == true
    end

    private

    # Creates the relationship via the adapter using Cyrel.
    def create_relationship
      # Ensure nodes are persisted and have IDs
      raise 'Source node must be persisted to create relationship' unless from_node.persisted? && from_node.internal_id
      raise 'Target node must be persisted to create relationship' unless to_node.persisted? && to_node.internal_id

      props_to_create = attributes_for_persistence

      # TODO: Implement Cyrel query generation
      # Example:
      # query = Cyrel.match(Cyrel.node(from_node.class.label_name).as(:a).where(id: from_node.internal_id))
      #              .match(Cyrel.node(to_node.class.label_name).as(:b).where(id: to_node.internal_id))
      #              .create(Cyrel.node(:a).rel(:out, self.class._relationship_type, props_to_create).as(:r).to(:b))
      #              .return(Cyrel.id(:r).as(:internal_id))
      cypher = "MATCH (a:#{from_node.class.label_name}), (b:#{to_node.class.label_name}) " \
               'WHERE id(a) = $from_id AND id(b) = $to_id ' \
               "CREATE (a)-[r:#{self.class._relationship_type} $props]->(b) " \
               'RETURN id(r)' # Placeholder
      params = { from_id: from_node.internal_id, to_id: to_node.internal_id, props: props_to_create }

      result = self.class.connection.execute_cypher(cypher, params, 'Create Relationship')

      new_id = result.first[:'id(r)'] # Assumes result structure
      self.internal_id = new_id if new_id

      @new_record = false
      changes_applied
      true
    end

    # Updates relationship properties via the adapter using Cyrel.
    def update_relationship
      props_to_update = changes_to_save
      return true if props_to_update.empty?

      # TODO: Implement Cyrel query generation
      # Example:
      # query = Cyrel.match(...).where(Cyrel.id(rel_alias).eq(internal_id)).set(rel_alias => props_to_update)
      cypher = 'MATCH ()-[r]-() WHERE id(r) = $id SET r += $props' # Placeholder
      params = { id: internal_id, props: props_to_update }

      self.class.connection.execute_cypher(cypher, params, 'Update Relationship')
      changes_applied
      true
    end

    # Helper to get attributes suitable for persistence.
    def attributes_for_persistence
      attributes.except('internal_id')
    end
  end
end
