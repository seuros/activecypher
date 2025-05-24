# frozen_string_literal: true

# lib/active_cypher/relationship.rb
# ------------------------------------------------------------------
#  Graph *edge* model — mirrors ActiveRecord::Base but for Cypher
#  relationships.
#
#  Example:
#
#     class WorksAtRelationship < ApplicationGraphRelationship
#       from_class 'PersonNode'
#       to_class   'CompanyNode'
#       type       'WORKS_AT'
#
#       attribute :title, :string
#       attribute :since, :integer
#     end
#
#  Persist with:
#
#     WorksAtRelationship.create({title: 'CTO'},
#                                from_node: person,
#                                to_node:   company)
# ------------------------------------------------------------------
require 'active_model'
require 'active_support'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/hash/indifferent_access'

module ActiveCypher
  class Relationship
    # Define connects_to_mappings as a class attribute to match ActiveCypher::Base
    class_attribute :connects_to_mappings, default: {}

    # --------------------------------------------------------------
    # Mix‑ins
    # --------------------------------------------------------------
    include ActiveModel::API
    include ActiveModel::Attributes
    include ActiveModel::Dirty
    include ActiveModel::Naming

    include Model::ConnectionOwner
    include Logging
    include Model::Abstract
    include Model::ConnectionHandling
    include Model::Callbacks
    include Model::Countable

    # --------------------------------------------------------------
    # Attributes
    # --------------------------------------------------------------
    # internal_id: Your relationship's social security number, but less secure
    # String because Neo4j relationships have commitment issues and need complex IDs
    # Memgraph relationships just want a simple number, like the good old days with MS Access.
    attribute :internal_id, :string

    # --------------------------------------------------------------
    # Connection fallback
    # --------------------------------------------------------------
    # Relationship classes usually share the same Bolt pool as the
    # node they originate from; delegate there unless the relationship
    # class was given its own pool explicitly.
    #
    #   WorksAtRelationship.connection  # -> PersonNode.connection
    #
    def self.connection
      # If a node_base_class is set (directly or by convention), always delegate to its connection
      if (klass = node_base_class)
        return klass.connection
      end

      return @connection if defined?(@connection) && @connection

      begin
        from_class.constantize.connection
      rescue StandardError
        nil
      end
    end

    # --------------------------------------------------------------
    # DSL helpers
    # --------------------------------------------------------------
    class_attribute :_from_class_name,   instance_writer: false
    class_attribute :_to_class_name,     instance_writer: false
    class_attribute :_relationship_type, instance_writer: false
    class_attribute :_node_base_class,   instance_writer: false

    class << self
      attr_reader :last_internal_id

      # DSL for setting or getting the node base class for connection delegation
      def node_base_class(klass = nil)
        if klass.nil?
          # If not set, try convention: XxxRelationship -> XxxNode
          return _node_base_class if _node_base_class

          if name&.end_with?('Relationship')
            node_base_name = name.sub(/Relationship\z/, 'Node')
            begin
              node_base_klass = node_base_name.constantize
              if node_base_klass.respond_to?(:abstract_class?) && node_base_klass.abstract_class?
                self._node_base_class = node_base_klass
                return node_base_klass
              end
            rescue NameError
              # Do nothing, fallback to nil
            end
          end
          return _node_base_class
        end
        # Only allow setting on abstract relationship base classes
        raise "Cannot set node_base_class on non-abstract relationship class #{name}" unless abstract_class?
        unless klass.respond_to?(:abstract_class?) && klass.abstract_class?
          raise ArgumentError, "node_base_class must be an abstract node base class (got #{klass})"
        end

        self._node_base_class = klass
      end

      # Prevent subclasses from overriding node_base_class
      def inherited(subclass)
        super
        return unless _node_base_class

        subclass._node_base_class = _node_base_class
        def subclass.node_base_class(*)
          raise "Cannot override node_base_class in subclass #{name}; it is locked to #{_node_base_class}"
        end
      end

      # -- endpoints ------------------------------------------------
      def from_class(value = nil)
        return _from_class_name if value.nil?

        self._from_class_name = value.to_s
      end
      alias from_class_name from_class

      def to_class(value = nil)
        return _to_class_name if value.nil?

        self._to_class_name = value.to_s
      end
      alias to_class_name to_class

      # -- type -----------------------------------------------------
      def type(value = nil)
        return _relationship_type if value.nil?

        self._relationship_type = value.to_s.upcase
      end
      alias relationship_type type

      # -- factories -----------------------------------------------
      # Mirrors ActiveRecord.create
      def create(attrs = {}, from_node:, to_node:)
        new(attrs, from_node: from_node, to_node: to_node).tap(&:save)
      end

      # Instantiate from DB row, marking the instance as persisted.
      def instantiate(attributes, from_node: nil, to_node: nil)
        instance = allocate
        instance.send(:init_with_attributes,
                      attributes,
                      from_node: from_node,
                      to_node: to_node)
        instance
      end
    end

    # --------------------------------------------------------------
    # Life‑cycle
    # --------------------------------------------------------------
    attr_accessor :from_node, :to_node
    attr_reader   :new_record

    def initialize(attrs = {}, from_node: nil, to_node: nil)
      _run(:initialize) do
        super()
        assign_attributes(attrs) if attrs
        @from_node  = from_node
        @to_node    = to_node
        @new_record = true
        clear_changes_information
      end
    end

    def new_record?  = @new_record
    def persisted?   = !new_record? && internal_id.present?
    def destroyed?   = @destroyed == true

    # --------------------------------------------------------------
    # Persistence API
    # --------------------------------------------------------------
    def save
      _run(:save) do
        if new_record?
          _run(:create) { create_relationship }
        else
          _run(:update) { update_relationship }
        end
      end
    rescue StandardError => e
      log_error "Failed to save #{self.class}: #{e.class} – #{e.message}"
      false
    end

    def destroy
      _run(:destroy) do
        raise 'Cannot destroy a new relationship' if new_record?
        raise 'Relationship already destroyed'    if destroyed?

        adapter = self.class.connection.id_handler

        cypher = "MATCH ()-[r]-() WHERE #{adapter.with_direct_id(internal_id)} DELETE r"
        params = {}

        self.class.connection.execute_cypher(cypher, params, 'Destroy Relationship')
        @destroyed = true
        freeze
        true
      end
    rescue StandardError => e
      log_error "Failed to destroy #{self.class}: #{e.class} – #{e.message}"
      false
    end

    # --------------------------------------------------------------
    # Private helpers
    # --------------------------------------------------------------
    private

    def create_relationship
      raise 'Source node must be persisted' unless from_node&.persisted?
      raise 'Target node must be persisted' unless to_node&.persisted?

      props  = attributes.except('internal_id').compact
      rel_ty = self.class.relationship_type
      arrow  = '->' # outgoing by default

      adapter = self.class.connection.id_handler
      parts = []

      # Build the Cypher query based on the adapter
      id_clause = adapter.with_direct_node_ids(from_node.internal_id, to_node.internal_id)
      parts << "MATCH (p), (h) WHERE #{id_clause}"
      parts << "CREATE (p)-[r:#{rel_ty}]#{arrow}(h)"
      parts << 'SET r += $props' unless props.empty? # only if we have props
      parts << "RETURN #{adapter.return_id}"

      cypher = parts.join(' ')
      params = { props: props }

      # Execute Cypher query
      result = self.class.connection.execute_cypher(cypher, params, 'Create Relationship')

      row = result.first

      # Try different ways to access the ID
      rid_sym = row && row[:rid]
      rid_str = row && row['rid']

      rid = rid_sym || rid_str

      raise 'Relationship creation returned no id' if rid.nil?

      self.internal_id = rid
      self.class.instance_variable_set(:@last_internal_id, rid)
      @new_record = false
      changes_applied
      true
    rescue StandardError => e
      log_error "Failed to save #{self.class}: #{e.class} – #{e.message}"
      false
    end

    def update_relationship
      changes = changes_to_save
      return true if changes.empty?

      adapter = self.class.connection.id_handler

      cypher = <<~CYPHER
        MATCH ()-[r]-() WHERE #{adapter.with_direct_id(internal_id)}
        SET r += $props
      CYPHER

      params = { props: changes }

      self.class.connection.execute_cypher(cypher, params, 'Update Relationship')
      changes_applied
      true
    end

    def changes_to_save = changes.transform_values(&:last)
  end
end
