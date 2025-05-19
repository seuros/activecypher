# frozen_string_literal: true

module ActiveCypher
  module ConnectionAdapters
    class MemgraphAdapter < AbstractBoltAdapter
      # Register this adapter with the registry
      Registry.register('memgraph', self)

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

      # Memgraph defaults to **implicit auto‑commit** transactions :contentReference[oaicite:1]{index=1},
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

      class ProtocolHandler < AbstractProtocolHandler
        def extract_version(agent)
          agent[%r{Memgraph/([\d.]+)}, 1] || 'unknown'
        end
      end
    end
  end
end
