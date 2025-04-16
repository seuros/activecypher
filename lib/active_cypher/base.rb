# frozen_string_literal: true

module ActiveCypher
  # @!parse
  #   # The One True Base Class. All node models must kneel before it.
  #   # If you ever wondered what ActiveRecord would look like after a long weekend and a midlife crisis, here you go.
  class Base
    # @!attribute [rw] connects_to_mappings
    #   @return [Hash] Because every base class needs a mapping it will never use directly.
    class_attribute :connects_to_mappings, default: {}
    include Logging

    # Let's just include every concern we can find, because why not.
    include Model::Core
    include Model::Attributes
    include Model::ConnectionOwner
    include Model::Callbacks
    include Model::Persistence
    include Model::Querying
    include Model::ConnectionHandling
    include Model::Destruction
    include Model::Abstract
    include Model::Countable
    include Model::Inspectable

    class << self
      # Attempts to retrieve a connection from the handler.
      # If you don't have a pool, you get to enjoy the fallback logic.
      # If you still don't have a connection, you get an error. It's the circle of life.
      # @return [Object] The connection instance
      def connection
        if (pool = connection_handler.pool(current_role, current_shard))
          return pool.connection
        end

        # fall back to a per‑model connection created by establish_connection
        return @connection if defined?(@connection) && @connection&.active?

        raise ActiveCypher::ConnectionNotEstablished,
              "No pool for role=#{current_role.inspect} shard=#{current_shard.inspect}"
      end
    end

    # Because Rails needs to feel included, too.
    ActiveSupport.run_load_hooks(:active_cypher, self)
  end
end
