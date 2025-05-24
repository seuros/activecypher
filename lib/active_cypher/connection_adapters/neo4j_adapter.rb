# frozen_string_literal: true

module ActiveCypher
  module ConnectionAdapters
    class Neo4jAdapter < AbstractBoltAdapter
      Registry.register('neo4j', self)

      def vendor = :neo4j

      def schema_catalog
        idx_rows = run('SHOW INDEXES')
        con_rows = run('SHOW CONSTRAINTS')

        idx_defs = idx_rows.map do |r|
          Schema::IndexDef.new(
            r['name'],
            r['entityType'].downcase.to_sym,
            r['labelsOrTypes'].first,
            r['properties'],
            r['uniqueness'] == 'UNIQUE',
            r['type'] == 'VECTOR' ? r['options'] : nil
          )
        end

        con_defs = con_rows.map do |r|
          Schema::ConstraintDef.new(
            r['name'],
            r['labelsOrTypes'].first,
            r['properties'],
            r['type'].split('_').first.downcase.to_sym
          )
        end

        Schema::Catalog.new(indexes: idx_defs, constraints: con_defs,
                            node_types: [], edge_types: [])
      rescue StandardError
        Schema::Catalog.new(indexes: [], constraints: [], node_types: [], edge_types: [])
      end

      # Use elementId() for Neo4j
      ID_FUNCTION = 'elementId'

      # Helper methods for Cypher query generation with IDs
      def self.with_direct_id(id)
        "elementId(r) = #{id}"
      end

      def self.with_param_id
        'elementId(r) = $id'
      end

      def self.with_direct_node_ids(a_id, b_id)
        "elementId(p) = #{a_id} AND elementId(h) = #{b_id}"
      end

      def self.with_param_node_ids
        'elementId(p) = $from_id AND elementId(h) = $to_id'
      end

      def self.return_id
        'elementId(r) AS rid'
      end

      # Additional helper methods for nodes
      def self.node_id_where(alias_name, param_name = nil)
        if param_name
          "elementId(#{alias_name}) = $#{param_name}"
        else
          "elementId(#{alias_name})"
        end
      end

      def self.node_id_equals_value(alias_name, value)
        # Quote string values for Cypher because Neo4j is paranoid about injection attacks
        # (As it should be, have you seen what people try to inject these days?)
        quoted_value = value.is_a?(String) ? "'#{value}'" : value
        "elementId(#{alias_name}) = #{quoted_value}"
      end

      def self.return_node_id(alias_name, as_name = 'internal_id')
        "elementId(#{alias_name}) AS #{as_name}"
      end

      def self.id_function
        'elementId'
      end

      # Return self as id_handler for compatibility
      def id_handler
        self.class
      end

      def execute_cypher(cypher, params = {}, ctx = 'Query')
        connect
        # Replace adapter-aware placeholder with Neo4j's elementId function
        cypher = cypher.gsub('__NODE_ID__', 'elementId')
        
        session = connection.session # thin wrapper around Bolt::Session
        result  = session.write_transaction do |tx|
          logger.debug { "[#{ctx}] #{cypher} #{params.inspect}" }
          tx.run(cypher, prepare_params(params))
        end
        process_records(result.to_a)
      ensure
        session&.close
      end

      # Explicit TX helpers — optional but handy.
      def begin_transaction(**) = (@tx = @connection.session.begin_transaction(**))
      def commit_transaction(_)   = @tx&.commit
      def rollback_transaction(_) = @tx&.rollback

      # Implement database-specific methods

      def convert_access_mode(mode)
        case mode.to_s
        when 'r', 'read'
          'r'
        when 'w', 'write'
          'w'
        else
          'w' # Default to write
        end
      end

      def prepare_tx_metadata(metadata, db, access_mode)
        # Handle Neo4j-specific metadata
        metadata['db'] = db if db
        metadata['mode'] = convert_access_mode(access_mode)
        metadata.compact
      end

      module Persistence
        include PersistenceMethods
        module_function :create_record, :update_record, :destroy_record
      end

      protected

      def protocol_handler_class = ProtocolHandler

      def validate_connection
        raise ActiveCypher::ConnectionError, "Server at #{config[:uri]} is not Neo4j" unless connection.server_agent.to_s.include?('Neo4j/')

        true
      end

      class ProtocolHandler < AbstractProtocolHandler
        def extract_version(agent) = agent[%r{Neo4j/([\d.]+)}, 1] || 'unknown'
      end
    end
  end
end
