# frozen_string_literal: true

module ActiveCypher
  module ConnectionAdapters
    class MemgraphAdapter < AbstractBoltAdapter
      # Register this adapter with the registry
      Registry.register('memgraph', self)

      def vendor = :memgraph

      def schema_catalog
        rows = run('SHOW SCHEMA')
        parse_schema(rows)
      rescue StandardError
        introspect_fallback
      end

      # Use id() for Memgraph instead of elementId()
      ID_FUNCTION = 'id'

      # Helper methods for Cypher query generation with IDs
      def self.with_direct_id(id)
        "id(r) = #{id}"
      end

      def self.with_param_id
        'id(r) = $id'
      end

      def self.with_direct_node_ids(a_id, b_id)
        "id(p) = #{a_id} AND id(h) = #{b_id}"
      end

      def self.with_param_node_ids
        'id(p) = $from_id AND id(h) = $to_id'
      end

      def self.return_id
        'id(r) AS rid'
      end

      # Return self as id_handler for compatibility with tests
      def id_handler
        self.class
      end

      # Override run to execute queries without explicit transactions
      # Memgraph auto‑commits each query, so we send RUN + PULL directly
      def run(cypher, params = {}, context: 'Query', db: nil, access_mode: :write)
        connect
        logger.debug { "[#{context}] #{cypher} #{params.inspect}" }

        instrument_query(cypher, params, context: context, metadata: { db: db, access_mode: access_mode }) do
          session = Bolt::Session.new(connection)

          rows = session.run_transaction(access_mode, db: db) do |tx|
            result = tx.run(cypher, prepare_params(params))
            result.respond_to?(:to_a) ? result.to_a : result
          end

          session.close
          rows
        end
      end

      # Memgraph defaults to **implicit auto‑commit** transactions
      # so we simply run the Cypher and return the rows.
      def execute_cypher(cypher, params = {}, ctx = 'Query')
        rows = run(cypher.gsub(/\belementId\(/i, 'id('), params, context: ctx)
        process_records(rows)
      end

      # Implement database-specific methods for Memgraph

      def convert_access_mode(mode)
        # Memgraph doesn't distinguish between read/write modes
        # but we'll keep the conversion here for consistency
        mode.to_s
      end

      def prepare_tx_metadata(metadata, _db, _access_mode)
        # Memgraph doesn't use db or access_mode in metadata
        # but we'll ensure metadata is returned with compact
        metadata.compact
      end

      protected

      def parse_schema(rows)
        nodes = []
        edges = []
        idx = []
        cons = []

        rows.each do |row|
          case row['type']
          when 'NODE'
            nodes << Schema::NodeTypeDef.new(row['label'], row['properties'], row['primaryKey'])
          when 'EDGE'
            edges << Schema::EdgeTypeDef.new(row['label'], row['from'], row['to'], row['properties'])
          when 'INDEX'
            idx << Schema::IndexDef.new(row['name'], :node, row['label'], row['properties'], row['unique'], nil)
          when 'CONSTRAINT'
            cons << Schema::ConstraintDef.new(row['name'], row['label'], row['properties'], :unique)
          end
        end

        Schema::Catalog.new(indexes: idx, constraints: cons, node_types: nodes, edge_types: edges)
      end

      def introspect_fallback
        labels = run('MATCH (n) RETURN DISTINCT labels(n) AS lbl').flat_map { |r| r['lbl'] }

        nodes = labels.map do |lbl|
          props = run("MATCH (n:`#{lbl}`) WITH n LIMIT 100 UNWIND keys(n) AS k RETURN DISTINCT k").map { |r| r['k'] }
          Schema::NodeTypeDef.new(lbl, props, nil)
        end

        Schema::Catalog.new(indexes: [], constraints: [], node_types: nodes, edge_types: [])
      end

      def protocol_handler_class = ProtocolHandler

      def validate_connection
        raise ActiveCypher::ConnectionError, "Server at #{config[:uri]} is not Memgraph" unless connection.server_agent.to_s.include?('Memgraph')

        true
      end

      # Override prepare_params to handle arrays correctly for Memgraph
      # Memgraph's UNWIND requires actual arrays/lists, not maps
      def prepare_params(raw)
        case raw
        when Hash  then raw.transform_keys(&:to_s).transform_values { |v| prepare_params(v) }
        when Array then raw.map { |v| prepare_params(v) } # Keep arrays as arrays for Memgraph
        when Time, Date, DateTime then raw.iso8601
        when Symbol then raw.to_s
        else raw # String/Integer/Float/Boolean/NilClass
        end
      end

      module Persistence
        include PersistenceMethods
        module_function :create_record, :update_record, :destroy_record
      end

      class ProtocolHandler < AbstractProtocolHandler
        def extract_version(agent)
          agent[%r{Memgraph/([\d.]+)}, 1] || 'unknown'
        end
      end
    end
  end
end
