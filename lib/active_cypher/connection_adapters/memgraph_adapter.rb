# frozen_string_literal: true

module ActiveCypher
  module ConnectionAdapters
    class MemgraphAdapter < AbstractBoltAdapter
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

      class ProtocolHandler < AbstractProtocolHandler
        def extract_version(agent)
          agent[%r{Memgraph/([\d.]+)}, 1] || 'unknown'
        end
      end
    end
  end
end
