# frozen_string_literal: true

require 'active_support/concern'

module ActiveCypher
  # Provides scoping capabilities for ActiveCypher models.
  # Allows defining reusable query constraints as class methods.
  module Scoping
    extend ActiveSupport::Concern

    included do
      # Stores defined scopes { scope_name: lambda }
      class_attribute :_scopes, instance_accessor: false, default: {}
      # Stores the default scope lambda
      class_attribute :_default_scope, instance_accessor: false, default: nil
    end

    class_methods do
      # Defines a scope for the model.
      #
      # A scope represents a commonly used query constraint that can be chained
      # like other query methods.
      #
      # @param name [Symbol] The name of the scope. This will define a class method
      #   with the same name.
      # @param body [Proc] A lambda or proc that implements the scope's logic.
      #   It will be called with the current relation (or the base model class)
      #   and any arguments passed to the scope. It should return a Relation.
      # @param block [Proc] Alternative way to pass the scope body as a block.
      #
      # @example
      #   class User < ActiveCypher::Base
      #     scope :active, -> { where(status: 'active') }
      #     scope :created_since, ->(date) { where("n.created_at > $date", date: date) } # Assuming Cyrel supports string conditions
      #   end
      #
      #   User.active.created_since(1.week.ago).to_a
      #
      def scope(name, body, &block)
        name = name.to_sym
        body = block if block_given?

        raise ArgumentError, 'The scope body needs to be a Proc or lambda.' unless body.is_a?(Proc)

        # Store the scope lambda
        self._scopes = _scopes.merge(name => body)

        # Define the class method for the scope
        # This method will apply the scope logic to the current relation or create a new one.
        define_singleton_method(name) do |*args|
          # Get the base relation (starts with all records of this model)
          base_relation = all

          # Execute the scope's lambda. It should return a Relation
          # containing the specific conditions of the scope.
          # We pass `self` (the model class) and any arguments.
          scope_relation = body.call(self, *args)

          unless scope_relation.is_a?(ActiveCypher::Relation)
            # If the lambda doesn't return a Relation, we might need to handle
            # merging conditions differently, but for now, enforce returning a Relation.
            raise ArgumentError, 'Scope body must return an ActiveCypher::Relation.'
          end

          # Merge the scope's relation into the base relation.
          # The `merge` method (currently a placeholder) is responsible
          # for combining the Cyrel queries correctly.
          base_relation.merge(scope_relation)
        end
      end

      # Defines the default scope for the model.
      #
      # The default scope is automatically applied to all queries for the model
      # unless explicitly removed using `unscoped`.
      #
      # @param body [Proc] A lambda or proc defining the default scope conditions.
      #   It should return an ActiveCypher::Relation.
      # @param block [Proc] Alternative way to pass the scope body as a block.
      #
      # @example
      #   class Post < ActiveCypher::Base
      #     default_scope -> { where(published: true) }
      #   end
      #
      #   Post.all # Automatically applies `where(published: true)`
      #
      def default_scope(body = nil, &block)
        body = block if block_given?

        raise ArgumentError, 'The default scope body must be a Proc or lambda, or nil to remove.' unless body.nil? || body.is_a?(Proc)

        self._default_scope = body
      end
    end
  end
end
