# frozen_string_literal: true

module ActiveCypher
  module Model
    # @!parse
    #   # Querying: The module that lets you pretend your graph is just a really weird table.
    #   # Because what’s more fun than chaining scopes and pretending you’re not writing Cypher by hand?
    module Querying
      extend ActiveSupport::Concern

      class_methods do
        # -- default label -----------------------------------------------
        # Returns the symbolic label name for the model, e.g., :user_node
        # @return [Symbol] The label name for the model
        def label_name = model_name.element.to_sym

        # -- basic query builders ----------------------------------------
        # Return a base Relation, applying the default scope if it exists
        # @return [Relation] The base relation for the model
        # Because nothing says "default" like a scope you forgot you set.
        def all
          relation = Relation.new(self)
          relation = relation.merge(_default_scope.call(self)) if _default_scope
          relation
        end

        # Proxy methods to chain basic query clauses off `all`
        # @param conditions [Hash, Cyrel::Expression::Base] The conditions for the where clause
        # @return [Relation]
        def where(conditions) = all.where(conditions)

        # @param val [Integer] The limit value
        # @return [Relation]
        def limit(val)        = all.limit(val)

        # @return [Relation]
        def order(*)          = all.order(*)

        # -- find / create -----------------------------------------------
        # Find a node by internal DB ID. Returns the record or dies dramatically.
        # @param internal_db_id [String] The internal database ID
        # @return [Object] The found record
        # @raise [ActiveCypher::RecordNotFound] if not found
        # Because sometimes you want to find a node, and sometimes you want to find existential dread.
        def find(internal_db_id)
          node_alias = :n

          # Always use just the primary label for database operations
          label = label_name

          query = Cyrel
                  .match(Cyrel.node(node_alias, labels: [label]))
                  .where(Cyrel.element_id(node_alias).eq(internal_db_id))
                  .return_(node_alias, Cyrel.element_id(node_alias).as(:internal_id))
                  .limit(1)

          Relation.new(self, query).first or
            raise ActiveCypher::RecordNotFound,
                  "#{name} with internal_id=#{internal_db_id.inspect} not found"
        end

        # Instantiates and immediately saves a new record. YOLO mode.
        # @param attrs [Hash] Attributes for the new record
        # @return [Object] The new, possibly persisted record
        # Because sometimes you just want to live dangerously.
        def create(attrs = {}) = new(attrs).tap(&:save)
      end
    end
  end
end
