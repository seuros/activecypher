# frozen_string_literal: true

module ActiveCypher
  module Model
    # Mixin for anything that “owns” a connection (nodes, relationships, maybe
    # graph‑level service objects later). 100 % framework‑agnostic.
    module ConnectionOwner
      extend ActiveSupport::Concern
      include ActiveCypher::Logging
      include ActiveCypher::Model::ConnectionHandling

      class_methods do
        # One handler for all subclasses that include this concern
        def connection_handler
          if defined?(@connection_handler) && @connection_handler
            @connection_handler
          elsif superclass.respond_to?(:connection_handler)
            superclass.connection_handler
          else
            @connection_handler = ActiveCypher::ConnectionHandler.new
          end
        end

        # Returns the adapter class being used by this model
        def adapter_class
          conn = connection
          conn&.class
        end

        # Always dynamically fetch the connection for the current db_key
        def connection
          handler = connection_handler

          if respond_to?(:connects_to_mappings) && connects_to_mappings.is_a?(Hash)
            db_key = connects_to_mappings[:writing] # Default to :writing mapping
            if db_key && (pool = handler.pool(db_key))
              return pool.connection
            end
          end

          return superclass.connection if superclass.respond_to?(:connection)

          raise ActiveCypher::ConnectionNotEstablished,
                "No connection pool found for #{name}, db_key=#{db_key.inspect}"
        end
      end

      # Instance method to access the adapter class
      def adapter_class
        self.class.adapter_class
      end

      # Instance method to access the connection dynamically
      def connection
        self.class.connection
      end
    end
  end
end
