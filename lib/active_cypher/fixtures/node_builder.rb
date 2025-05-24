# frozen_string_literal: true

module ActiveCypher
  module Fixtures
    class NodeBuilder
      # Builds a node and registers it like a bouncer at a VIP graph party.
      #
      # @param ref [Symbol, String] Logical ref name (e.g., :john, :spaceship_42)
      # @param model_class [Class] The model class (must know how to connect and label itself)
      # @param props [Hash] Properties to assign to the node
      # @return [Object] Instantiated model object with DB-assigned internal_id
      def self.build(ref, model_class, props)
        conn = model_class.connection
        labels = model_class.labels

        # Because even Cypher likes a well-dressed node.
        label_clause = labels.map { |label| "`#{label}`" }.join(':')

        # Build and fire the CREATE query.
        # Ask the adapter how it likes its IDs served - string or integer, sir?
        adapter = conn.id_handler
        cypher = <<~CYPHER
          CREATE (n:#{label_clause} $props)
          RETURN n, #{adapter.return_node_id('n')}, properties(n) AS props
        CYPHER

        result = conn.execute_cypher(cypher, props: props)
        record = result.first

        # Extract properties returned by the DB
        node_props = record[:props] || record['props'] || {}
        node_props['internal_id'] = record[:internal_id] || record['internal_id']

        # Instantiate and tag it like we own it
        instance = model_class.instantiate(node_props)
        Registry.add(ref, instance)
        instance
      end

      # Bulk create nodes. Still uses single `CREATE` per node,
      # just slices the list to avoid melting your graph engine.
      #
      # @param nodes [Array<Hash>] List of { ref:, model_class:, props: }
      # @param batch_size [Integer] How many to process per slice
      def self.bulk_build(nodes, batch_size: 200)
        nodes.each_slice(batch_size) do |batch|
          batch.each do |node|
            build(node[:ref], node[:model_class], node[:props])
          end
        end
      end
    end
  end
end
