# frozen_string_literal: true

module ActiveCypher
  module ConnectionAdapters
    class Neo4jAdapter < AbstractBoltAdapter
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
