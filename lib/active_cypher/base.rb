# frozen_string_literal: true

require 'active_model'
require 'active_model/validations'
require 'active_model/callbacks'
require 'active_model/attributes'
require 'active_model/dirty'

module ActiveCypher
  # @!parse
  #   # The One True Base Class. All node models must kneel before it.
  #   # If you ever wondered what ActiveRecord would look like after a long weekend and a midlife crisis, here you go.
  class Base
    # @!attribute [rw] connects_to_mappings
    #   @return [Hash] Because every base class needs a mapping it will never use directly.
    class_attribute :connects_to_mappings, default: {}

    # Rails/ActiveModel foundations
    include Logging
    include ActiveModel::Model
    include ActiveModel::Validations
    include ActiveModel::Callbacks
    include ActiveModel::Attributes
    include ActiveModel::Dirty

    # Let's just include every concern we can find, because why not.
    include Model::Core
    include Model::Callbacks
    include Model::Labelling
    include Model::Querying
    include Model::Abstract
    include Model::Attributes
    include Model::ConnectionOwner
    include Model::Persistence
    include Model::Destruction
    include Model::Countable

    class << self
      # Attempts to retrieve a connection from the handler.
      # If you don't have a pool, you get to enjoy the fallback logic.
      # If you still don't have a connection, you get an error. It's the circle of life.
      # @return [Object] The connection instance
      def connection
        # Determine the current role (e.g., :writing, :reading)
        # ActiveCypher::RuntimeRegistry.current_role defaults to :writing
        # Only use db_key for pool lookup
        if respond_to?(:connects_to_mappings) && connects_to_mappings.is_a?(Hash)
          db_key = connects_to_mappings[:writing] # or whichever role is appropriate
          if db_key && (pool = connection_handler.pool(db_key))
            return pool.connection
          end
        end

        return @connection if defined?(@connection) && @connection&.active?

        raise ActiveCypher::ConnectionNotEstablished,
              "No connection pool found for graph #{name}, db_key=#{db_key.inspect}. " \
              'Ensure `connects_to` is configured for this model or its ancestors, ' \
              'and `cypher_databases.yml` has the corresponding entries.'
      end
    end

    # Custom object inspection method for pretty-printing a compact,
    # single-line summary of the object. Output examples:
    #
    #   #<UserNode id="26" name="Alice" age=34>   => persisted object
    #   #<UserNode (new) name="Bob">              => object not yet saved
    #
    def inspect
      # Put 'internal_id' first like it's the main character (even if it's nil)
      ordered = attributes.dup
      ordered = ordered.slice('internal_id').merge(ordered.except('internal_id'))

      # Turn each attr into "key: value" because we humans fear raw hashes
      parts = ordered.map { |k, v| "#{k}: #{v.inspect}" }

      # Wrap it all up in a fake-sane object string, so you can pretend your data is organized.
      "#<#{self.class} #{parts.join(', ')}>"
    end

    # Because Rails needs to feel included, too.
    ActiveSupport.run_load_hooks(:active_cypher, self)
  end
end
