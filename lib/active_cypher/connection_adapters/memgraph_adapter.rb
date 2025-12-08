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

      # Additional helper methods for nodes
      def self.node_id_where(alias_name, param_name = nil)
        if param_name
          "id(#{alias_name}) = $#{param_name}"
        else
          "id(#{alias_name})"
        end
      end

      def self.node_id_equals_value(alias_name, value)
        "id(#{alias_name}) = #{value}"
      end

      def self.return_node_id(alias_name, as_name = 'internal_id')
        "id(#{alias_name}) AS #{as_name}"
      end

      def self.id_function
        'id'
      end

      # Return self as id_handler for compatibility with tests
      def id_handler
        self.class
      end

      # Memgraph uses different constraint syntax than Neo4j
      def ensure_schema_migration_constraint
        execute_ddl(<<~CYPHER)
          CREATE CONSTRAINT ON (m:SchemaMigration) ASSERT m.version IS UNIQUE
        CYPHER
      rescue ActiveCypher::QueryError => e
        # Ignore if constraint already exists
        raise unless e.message.include?('already exists')
      end

      # Execute DDL statements (constraints, indexes) without explicit transaction
      # Memgraph requires auto-commit for schema manipulation
      def execute_ddl(cypher, params = {})
        connect
        logger.debug { "[DDL] #{cypher}" }

        Sync do
          # Send RUN directly without BEGIN/COMMIT wrapper
          connection.write_message(Bolt::Messaging::Run.new(cypher, params, {}))
          connection.write_message(Bolt::Messaging::Pull.new({ n: -1 }))

          # Read responses
          run_response = connection.read_message
          unless run_response.is_a?(Bolt::Messaging::Success)
            # Read any remaining messages to clear connection state
            begin
              connection.read_message
            rescue StandardError
              nil
            end
            # Send RESET to clear connection state
            connection.write_message(Bolt::Messaging::Reset.new)
            begin
              connection.read_message
            rescue StandardError
              nil
            end
            raise QueryError, "DDL failed for: #{cypher.inspect}\nError: #{run_response.fields.first}"
          end

          pull_response = connection.read_message
          pull_response
        end
      end

      # Override run to execute queries using auto-commit mode.
      # Memgraph auto-commits each query, so we send RUN + PULL directly
      # without BEGIN/COMMIT wrapper. This avoids transaction state issues.
      def run(cypher, params = {}, context: 'Query', db: nil, access_mode: :write)
        connect
        logger.debug { "[#{context}] #{cypher} #{params.inspect}" }

        instrument_query(cypher, params, context: context, metadata: { db: db, access_mode: access_mode }) do
          run_auto_commit(cypher, prepare_params(params))
        end
      end

      # Execute a query in auto-commit mode (no explicit transaction).
      # Sends RUN + PULL directly to the connection.
      #
      # @param cypher [String] The Cypher query
      # @param params [Hash] Query parameters
      # @return [Array<Hash>] The result rows
      def run_auto_commit(cypher, params = {})
        Sync do
          # Send RUN message
          run_meta = {}
          connection.write_message(Bolt::Messaging::Run.new(cypher, params, run_meta))

          # Read RUN response
          run_response = connection.read_message

          case run_response
          when Bolt::Messaging::Success
            # Send PULL to get results
            connection.write_message(Bolt::Messaging::Pull.new({ n: -1 }))

            # Collect records
            rows = []
            fields = run_response.metadata['fields'] || []

            loop do
              msg = connection.read_message
              case msg
              when Bolt::Messaging::Record
                # Convert record values to hash with field names
                row = fields.zip(msg.values).to_h
                rows << row
              when Bolt::Messaging::Success
                # End of results
                break
              when Bolt::Messaging::Failure
                code = msg.metadata['code']
                message = msg.metadata['message']
                connection.reset!
                raise QueryError, "Query failed: #{code} - #{message}"
              else
                raise ProtocolError, "Unexpected response during PULL: #{msg.class}"
              end
            end

            rows
          when Bolt::Messaging::Failure
            code = run_response.metadata['code']
            message = run_response.metadata['message']
            connection.reset!
            raise QueryError, "Query failed: #{code} - #{message}"
          else
            raise ProtocolError, "Unexpected response to RUN: #{run_response.class}"
          end
        end
      end

      # Memgraph defaults to **implicit auto‑commit** transactions
      # so we simply run the Cypher and return the rows.
      def execute_cypher(cypher, params = {}, ctx = 'Query')
        # Replace adapter-aware placeholder with Memgraph's id function
        # Because Memgraph insists on being different and using id() instead of elementId()
        cypher = cypher.gsub('__NODE_ID__', 'id')
        rows = run(cypher, params, context: ctx)
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

      # Hydrates attributes from a Memgraph record
      # @param record [Hash] The raw record from Memgraph
      # @param node_alias [Symbol] The alias used for the node in the query
      # @return [Hash] The hydrated attributes
      def hydrate_record(record, node_alias)
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
          # Use Cyrel for secure query building with user-provided label
          query = Cyrel::Query.new
                              .match(Cyrel.node(:n, lbl))
                              .with(:n)
                              .limit(100)
                              .unwind(Cyrel.function(:keys, :n), :k)
                              .return_('DISTINCT k')

          cypher, params = query.to_cypher
          props = run(cypher, params).map { |r| r['k'] }
          Schema::NodeTypeDef.new(lbl, props, nil)
        end

        Schema::Catalog.new(indexes: [], constraints: [], node_types: nodes, edge_types: [])
      end

      def protocol_handler_class = ProtocolHandler

      # Memgraph 3.7+ is expected. Earlier versions are untested and may not work.
      # See: https://memgraph.com/docs for version-specific features.
      MINIMUM_VERSION = '3.7'

      def validate_connection
        agent = connection.server_agent.to_s
        raise ActiveCypher::ConnectionError, "Server at #{config[:uri]} is not Memgraph" unless agent.include?('Memgraph')

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
