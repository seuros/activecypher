# frozen_string_literal: true

module ActiveCypher
  module Fixtures
    class RelBuilder
      # Builds a relationship between two nodes, enforcing cross-DB safety.
      #
      # @param _ref [Symbol, String] Logical reference for this relationship (not used for DB, but for registry/uniqueness)
      # @param from_ref [Symbol, String] Logical ref of the start node
      # @param type [Symbol, String] Relationship type (e.g., :LIKES)
      # @param to_ref [Symbol, String] Logical ref of the end node
      # @param props [Hash] Optional properties for the relationship
      # @raise [ActiveCypher::FixtureError] if cross-DB relationship is attempted
      # @return [void]
      def build(_ref, from_ref, type, to_ref, props = {})
        from = Registry.get(from_ref)
        to   = Registry.get(to_ref)

        raise FixtureError, "Missing from node: #{from_ref}" unless from
        raise FixtureError, "Missing to node: #{to_ref}" unless to

        from_conn = from.class.connection
        to_conn   = to.class.connection

        raise FixtureError, 'Cross-database relationship? Sorry, your data has commitment issues.' if from_conn != to_conn

        from_label = from.class.labels.first
        to_label   = to.class.labels.first

        cypher = <<~CYPHER
          MATCH (a:#{from_label} {name: $from_name}), (b:#{to_label} {name: $to_name})
          CREATE (a)-[r:#{type} $props]->(b)
          RETURN r
        CYPHER

        from_conn.execute_cypher(
          cypher,
          from_name: from.name,
          to_name: to.name,
          props: props
        )

        nil
      end

      # Bulk create relationships for performance using UNWIND batching
      # @param rels [Array<Hash>] relationship definitions (from DSLContext)
      # @param batch_size [Integer] batch size for UNWIND
      def self.bulk_build(rels, batch_size: 200)
        # Check all relationships for cross-DB violations first
        rels.each do |rel|
          from = Registry.get(rel[:from_ref])
          to = Registry.get(rel[:to_ref])
          raise FixtureError, "Both endpoints must exist: #{rel[:from_ref]}, #{rel[:to_ref]}" unless from && to

          from_conn = from.class.connection
          to_conn   = to.class.connection
          raise FixtureError, 'Cross-database relationship? Sorry, your data has commitment issues.' if from_conn != to_conn
        end

        # Group by connection
        grouped = rels.group_by do |rel|
          from = Registry.get(rel[:from_ref])
          from.class.connection
        end

        grouped.each do |conn, group|
          group.each_slice(batch_size) do |batch|
            unwind_batch = batch.map do |rel|
              from = Registry.get(rel[:from_ref])
              to   = Registry.get(rel[:to_ref])

              {
                from_name: from.name,
                from_label: from.class.labels.first,
                to_name: to.name,
                to_label: to.class.labels.first,
                props: rel[:props] || {},
                type: rel[:type].to_s
              }
            end

            cypher = <<~CYPHER
              UNWIND $rows AS row
              MATCH (a:#{unwind_batch.first[:from_label]} {name: row.from_name})
              MATCH (b:#{unwind_batch.first[:to_label]} {name: row.to_name})
              CREATE (a)-[r:#{unwind_batch.first[:type]} {props: row.props}]->(b)
            CYPHER

            conn.execute_cypher(cypher, rows: unwind_batch)
          end
        end
      end
    end
  end
end
