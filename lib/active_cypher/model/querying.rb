# frozen_string_literal: true

module ActiveCypher
  module Model
    # Querying: The module that lets you pretend your graph is just a really weird table.
    # Because what's more fun than chaining scopes and pretending you're not writing Cypher by hand?
    module Querying
      extend ActiveSupport::Concern

      class_methods do
        # -- Basic Query Builders ----------------------------------------

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

        def limit(val) = all.limit(val)

        def order(*) = all.order(*)

        # -- find / create ------------------------------------------------

        # Find a node by internal DB ID. Returns the record or dies dramatically.
        # Because sometimes you want to find a node, and sometimes you want to find existential dread.
        def find(internal_db_id)
          internal_db_id = internal_db_id.to_i if internal_db_id.respond_to?(:to_i)
          node_alias = :n

          labels = respond_to?(:labels) ? self.labels : [label_name]
          Cyrel.match(Cyrel.node(node_alias, labels: labels)).limit(1)
          label_string = labels.map { |l| ":#{l}" }.join
          cypher = <<~CYPHER
            MATCH (#{node_alias}#{label_string})
            WHERE id(#{node_alias}) = #{internal_db_id}
            RETURN #{node_alias}, id(#{node_alias}) AS internal_id
            LIMIT 1
          CYPHER

          result = connection.execute_cypher(cypher)
          record = result.first

          if record
            attrs = _hydrate_attributes_from_memgraph_record(record, node_alias)
            return instantiate(attrs)
          end

          raise ActiveCypher::RecordNotFound,
                "#{name} with internal_id=#{internal_db_id.inspect} not found. Perhaps it's in another castle, or just being 'graph'-ty."
        end

        # Instantiates and immediately saves a new record. YOLO mode.
        # @param attrs [Hash] Attributes for the new record
        # @return [Object] The new, possibly persisted record
        # Because sometimes you just want to live dangerously.
        def create(attrs = {}) = new(attrs).tap(&:save)

        private

        def _hydrate_attributes_from_memgraph_record(record, node_alias)
          attrs = {}
          node_data = record[node_alias] || record[node_alias.to_s]

          if node_data.is_a?(Array) && node_data.length >= 2
            properties_container = node_data[1]
            if properties_container.is_a?(Array) && properties_container.length >= 3
              properties = properties_container[2]
              properties.each { |k, v| attrs[k.to_sym] = v } if properties.is_a?(Hash)
            end
          elsif node_data.is_a?(Hash)
            node_data.each { |k, v| attrs[k.to_sym] = v }
          elsif node_data.respond_to?(:properties)
            attrs = node_data.properties.symbolize_keys
          end

          attrs[:internal_id] = record[:internal_id] || record['internal_id']
          attrs
        end
      end
    end
  end
end
