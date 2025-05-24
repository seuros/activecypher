# frozen_string_literal: true

module ActiveCypher
  module ConnectionAdapters
    # Common persistence helpers shared by adapters
    module PersistenceMethods
      # Create a record in the database and update model state.
      # @param model [ActiveCypher::Base, ActiveCypher::Relationship] the model instance
      # @return [Boolean] true if created successfully
      def create_record(model)
        props = model.send(:attributes_for_persistence)
        labels = if model.class.respond_to?(:labels)
                   model.class.labels
                 else
                   [model.class.label_name.to_s]
                 end
        label_string = labels.map { |l| ":#{l}" }.join

        adapter = model.connection.id_handler
        cypher = "CREATE (n#{label_string} $props) RETURN #{adapter.return_node_id('n')}"
        data = model.connection.execute_cypher(cypher, { props: props }, 'Create')

        return false if data.blank? || !data.first.key?(:internal_id)

        model.internal_id = data.first[:internal_id]
        model.instance_variable_set(:@new_record, false)
        model.send(:changes_applied)
        true
      end

      # Update a record in the database based on model changes.
      # @param model [ActiveCypher::Base, ActiveCypher::Relationship] the model instance
      # @return [Boolean] true if update succeeded
      def update_record(model)
        changes = model.send(:changes_to_save)
        return true if changes.empty?

        labels = if model.class.respond_to?(:labels)
                   model.class.labels
                 else
                   [model.class.label_name.to_s]
                 end

        label_string = labels.map { |l| ":#{l}" }.join
        set_clauses = changes.keys.map { |property| "n.#{property} = $#{property}" }.join(', ')

        adapter = model.connection.id_handler
        # Convert internal_id to its preferred existential format
        # Neo4j wants strings because it's complicated, Memgraph wants integers because it's not
        node_id_param = adapter.id_function == 'elementId' ? model.internal_id.to_s : model.internal_id.to_i
        params = changes.merge(node_id: node_id_param)

        cypher = "MATCH (n#{label_string}) WHERE #{adapter.node_id_where('n', 'node_id')} SET #{set_clauses} RETURN n"
        model.connection.execute_cypher(cypher, params, 'Update')

        model.send(:changes_applied)
        true
      end

      # Destroy a record in the database.
      # @param model [ActiveCypher::Base, ActiveCypher::Relationship] the model instance
      # @return [Boolean] true if a record was deleted
      def destroy_record(model)
        labels = if model.class.respond_to?(:labels)
                   model.class.labels
                 else
                   [model.class.label_name]
                 end
        label_string = labels.map { |l| ":#{l}" }.join

        adapter = model.connection.id_handler
        # Convert internal_id to whatever format makes the database feel validated
        # It's like therapy, but for graph databases
        node_id_param = adapter.id_function == 'elementId' ? model.internal_id.to_s : model.internal_id.to_i

        cypher = <<~CYPHER
          MATCH (n#{label_string})
          WHERE #{adapter.node_id_where('n', 'node_id')}
          DETACH DELETE n
          RETURN count(*) AS deleted
        CYPHER

        result = model.connection.execute_cypher(cypher, { node_id: node_id_param }, 'Destroy')
        result.present? && result.first[:deleted].to_i.positive?
      end
    end
  end
end
