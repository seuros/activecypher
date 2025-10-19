# frozen_string_literal: true

module ActiveCypher
  module Model
    # Mixin for anything that “owns” a connection (nodes, relationships, maybe
    # graph‑level service objects later). 100 % framework‑agnostic.
    module ConnectionOwner
      extend ActiveSupport::Concern
      include ActiveCypher::Logging
      include ActiveCypher::Model::ConnectionHandling

      def self.db_key_for(mapping, role)
        return nil unless mapping.is_a?(Hash)

        value = mapping[role]
        value = mapping[:writing] if value.nil?

        resolve_db_value(value, mapping[:writing])
      end

      def self.resolve_db_value(value, fallback, visited = nil)
        visited ||= []
        return nil if value.nil? && fallback.nil?

        case value
        when Hash
          hash_id = value.object_id
          return nil if visited.include?(hash_id)

          visited += [hash_id]

          shard = ActiveCypher::RuntimeRegistry.current_shard || :default
          shard_value = value[shard] || value[:default] || value.values.first
          resolve_db_value(shard_value, fallback, visited)
        else
          return value if value
          return nil unless fallback

          fallback_id = fallback.object_id
          return nil if visited.include?(fallback_id)

          visited += [fallback_id]
          resolve_db_value(fallback, nil, visited)
        end
      end
      private_class_method :resolve_db_value

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
          mapping = connects_to_mappings if respond_to?(:connects_to_mappings)
          role = ActiveCypher::RuntimeRegistry.current_role || :writing

          db_key = ConnectionOwner.db_key_for(mapping, role)
          db_key = db_key.to_sym if db_key.respond_to?(:to_sym)

          if db_key && (pool = handler.pool(db_key))
            return pool.connection
          end

          return superclass.connection if superclass.respond_to?(:connection)

          raise ActiveCypher::ConnectionNotEstablished,
                "No connection pool found for #{name}, db_key=#{db_key.inspect}"
        end

        # Switch the current role/shard for the duration of the block.
        # Mirrors ActiveRecord::Base.connected_to semantics on a smaller scale.
        def connected_to(role: nil, shard: nil)
          raise ArgumentError, 'connected_to requires a block' unless block_given?

          previous_role = ActiveCypher::RuntimeRegistry.current_role
          previous_shard = ActiveCypher::RuntimeRegistry.current_shard

          selected_role = role.nil? ? previous_role : role
          selected_role ||= :writing

          selected_shard = shard.nil? ? previous_shard : shard
          selected_shard ||= :default

          ActiveCypher::RuntimeRegistry.current_role = selected_role.to_sym
          ActiveCypher::RuntimeRegistry.current_shard = selected_shard.to_sym

          yield
        ensure
          ActiveCypher::RuntimeRegistry.current_role = previous_role
          ActiveCypher::RuntimeRegistry.current_shard = previous_shard
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
