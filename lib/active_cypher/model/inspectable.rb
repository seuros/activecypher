# frozen_string_literal: true

module ActiveCypher
  module Model
    # @!parse
    #   # Adds a custom inspect method for pretty-printing a compact, single-line summary of the object.
    #   # Because nothing says "debuggable" like a string that pretends your object is more interesting than it is.
    module Inspectable
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
    end
  end
end
