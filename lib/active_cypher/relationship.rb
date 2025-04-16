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

    class << self
      attr_reader :last_internal_id

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

        cypher = 'MATCH ()-[r]-() WHERE elementId(r) = $id DELETE r'
        params = { id: internal_id }

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

      parts  = []
      parts << 'MATCH (a) WHERE elementId(a) = $from_id'
      parts << 'MATCH (b) WHERE elementId(b) = $to_id'
      parts << "CREATE (a)-[r:#{rel_ty}]#{arrow}(b)"
      parts << 'SET r += $props' unless props.empty? # only if we have props
      parts << 'RETURN elementId(r) AS rid'

      cypher = parts.join(' ')
      params = {
        from_id: from_node.internal_id,
        to_id: to_node.internal_id,
        props: props
      }

      row = self.class.connection.execute_cypher(cypher, params, 'Create Relationship').first
      rid = row && (row[:rid] || row['rid']) or raise 'Relationship creation returned no id'

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

      cypher = <<~CYPHER
        MATCH ()-[r]-() WHERE elementId(r) = $id
        SET r += $props
      CYPHER
      params = { id: internal_id, props: changes }

      self.class.connection.execute_cypher(cypher, params, 'Update Relationship')
      changes_applied
      true
    end

    def changes_to_save = changes.transform_values(&:last)
  end
end
