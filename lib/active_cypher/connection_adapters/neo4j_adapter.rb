# frozen_string_literal: true

require 'active_cypher/schema/catalog'

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

      def execute_cypher(cypher, params = {}, ctx = 'Query')
        connect
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
        module_function

        def create_record(model)
          props = model.send(:attributes_for_persistence)
          labels = if model.class.respond_to?(:labels)
                     model.class.labels
                   else
                     [model.class.label_name.to_s]
                   end
          label_string = labels.map { |l| ":#{l}" }.join
          props_str = props.map do |k, v|
            value_str = if v.nil?
                          'NULL'
                        elsif v.is_a?(String)
                          "'#{v.gsub("'", "\\\\'")}'"
                        elsif v.is_a?(Numeric) || v.is_a?(TrueClass) || v.is_a?(FalseClass)
                          v.to_s
                        else
                          "'#{v.to_s.gsub("'", "\\\\'")}'"
                        end
            "#{k}: #{value_str}"
          end.join(', ')

          cypher = "CREATE (n#{label_string} {#{props_str}}) RETURN id(n) AS internal_id"
          data = model.connection.execute_cypher(cypher, {}, 'Create')

          return false if data.blank? || !data.first.key?(:internal_id)

          model.internal_id = data.first[:internal_id]
          model.instance_variable_set(:@new_record, false)
          model.send(:changes_applied)
          true
        end

        def update_record(model)
          changes = model.send(:changes_to_save)
          return true if changes.empty?

          labels = if model.class.respond_to?(:labels)
                     model.class.labels
                   else
                     [model.class.label_name]
                   end

          label_string = labels.map { |l| ":#{l}" }.join
          set_clauses = changes.map do |property, value|
            if value.nil?
              "n.#{property} = NULL"
            elsif value.is_a?(String)
              "n.#{property} = '#{value.gsub("'", "\\\\'")}'"
            elsif value.is_a?(Numeric) || value.is_a?(TrueClass) || value.is_a?(FalseClass)
              "n.#{property} = #{value}"
            else
              "n.#{property} = '#{value.to_s.gsub("'", "\\\\'")}'"
            end
          end.join(', ')

          cypher = "MATCH (n#{label_string}) WHERE id(n) = #{model.internal_id} SET #{set_clauses} RETURN n"
          model.connection.execute_cypher(cypher, {}, 'Update')

          model.send(:changes_applied)
          true
        end

        def destroy_record(model)
          labels = if model.class.respond_to?(:labels)
                     model.class.labels
                   else
                     [model.class.label_name]
                   end
          label_string = labels.map { |l| ":#{l}" }.join

          cypher = <<~CYPHER
            MATCH (n#{label_string})
            WHERE id(n) = #{model.internal_id}
            DETACH DELETE n
            RETURN count(*) AS deleted
          CYPHER

          result = model.connection.execute_cypher(cypher, {}, 'Destroy')
          if result.present? && result.first[:deleted].to_i.positive?
            model.instance_variable_set(:@destroyed, true)
            model.freeze
            true
          else
            false
          end
        end
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
