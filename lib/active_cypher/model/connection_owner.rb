# frozen_string_literal: true

module ActiveCypher
  module Model
    # Mixin for anything that “owns” a connection (nodes, relationships, maybe
    # graph‑level service objects later). 100 % framework‑agnostic.
    # @note Because every object wants to feel important by "owning" something, even if it's just a connection.
    # Moroccan black magick and Ruby sorcery may be involved in keeping these connections alive.
    module ConnectionOwner
      extend ActiveSupport::Concern
      include ActiveCypher::Logging
      include ActiveCypher::Model::ConnectionHandling

      included do
        # Every class gets its own adapter slot (overridden by establish_connection)
        # Because nothing says "flexibility" like a class variable you'll forget exists.
        # This is where the witchcraft happens: sometimes the right connection just appears.
        cattr_accessor :connection, instance_accessor: false
      end

      class_methods do
        delegate :current_role, :current_shard,
                 to: ActiveCypher::RuntimeRegistry

        # One handler for all subclasses that include this concern
        # Because sharing is caring, except when it comes to connection pools.
        # Summoned by Ruby wizardry: this handler is conjured once and shared by all.
        @@connection_handler ||= ActiveCypher::ConnectionHandler.new # rubocop:disable Style/ClassVars
        def connection_handler = @@connection_handler

        # Returns the adapter class being used by this model
        # @return [Class] The adapter class (e.g., Neo4jAdapter, MemgraphAdapter)
        def adapter_class
          conn = connection
          return nil unless conn

          conn.class
        end

        # Temporarily switches the current role and shard for the duration of the block.
        # @param role [Symbol, nil] The role to switch to
        # @param shard [Symbol] The shard to switch to
        # @yield The block to execute with the new context
        # @note Because sometimes you just want to pretend you're connected to something else for a while.
        # Warning: If you switch too often, you may summon unexpected spirits from the Ruby shadow dimension.
        def connected_to(role: nil, shard: :default)
          previous_role  = current_role
          previous_shard = current_shard
          ActiveCypher::RuntimeRegistry.current_role  = role  || previous_role
          ActiveCypher::RuntimeRegistry.current_shard = shard || previous_shard
          yield
        ensure
          ActiveCypher::RuntimeRegistry.current_role  = previous_role
          ActiveCypher::RuntimeRegistry.current_shard = previous_shard
        end
      end

      # Instance method to access the adapter class
      # @return [Class] The adapter class (e.g., Neo4jAdapter, MemgraphAdapter)
      def adapter_class
        self.class.adapter_class
      end
    end
  end
end
