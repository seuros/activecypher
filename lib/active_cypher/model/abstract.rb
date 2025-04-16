# frozen_string_literal: true

# Adds `self.abstract_class = true` support, mimicking ActiveRecord’s
# approach to abstract base classes. No runtime enforcement—just vibes,
# a sprinkle of Ruby sorcery, and the hope you know what you're doing.
# Because nothing says "enterprise" like a flag that means "please ignore me."
#
# This module gives every subclass an `abstract_class` boolean,
# along with the `abstract_class?` reader. You can assign this flag
# in your base class to signal “do not instantiate me,” like a digital
# “Do Not Resuscitate” order. It's the ORM equivalent of a velvet rope at a nightclub,
# or a protective circle against accidental instantiation.
#
# === Example
#
#   class ApplicationGraphNode < ActiveCypher::Base
#     self.abstract_class = true
#   end
#
#   class PersonNode < ApplicationGraphNode
#     attribute :name, :string
#   end
#
#   ApplicationGraphNode.abstract_class?  # => true
#   PersonNode.abstract_class?            # => false
#
# Querying an abstract class will raise a runtime error—
# eventually. Maybe. Down in the adapter layer where your dreams go to die.
# Or at least where your stacktraces go to get longer. If only you had a talisman
# against such errors—perhaps.
#
module ActiveCypher
  module Model
    # @!parse
    #   # Adds support for marking a class as abstract, so you can feel important and uninstantiable.
    #   # No runtime enforcement—just vibes, a dash of Ruby witchcraft, and the hope you know what you're doing.
    #   # It's the ORM equivalent of a velvet rope at a nightclub, or a magical ward against instantiation.
    module Abstract
      extend ActiveSupport::Concern

      included do
        # Define a per-class flag for abstract status.
        # Default is false, because chaos is opt-in.
        class_attribute :abstract_class, instance_accessor: false, default: false

        # Ensure subclasses are born concrete unless they say otherwise.
        # Because every child deserves a chance to disappoint you in its own way.
        # This is the Ruby equivalent of breaking the circle and letting the spirits loose.
        def self.inherited(subclass)
          super
          subclass.abstract_class = false
        end
      end

      class_methods do
        # Sets whether this class is abstract.
        #
        # @param value [Boolean] true to mark the class as abstract.
        # @return [void]
        def abstract_class=(value)
          self.abstract_class = !!value
        end

        # Checks if this class is abstract.
        #
        # @return [Boolean] true if the class is abstract.
        def abstract_class? = abstract_class

        # Override query methods to raise if called on an abstract class.
        # Because nothing says “don’t do that” like a runtime exception.
        # It's like a velvet rope for your ORM: "Sorry, you're not on the list."
        # If you try to cross this boundary, beware: you may awaken ancient bugs
        %i[all where limit order].each do |method|
          undef_method method if method_defined?(method)
          define_method(method) do |*args, **kw|
            if abstract_class?
              raise ActiveCypher::AbstractClassError,
                    "#{name} is abstract; `.#{method}` is not allowed. (But hey, at least you tried. Next time, bring a spellbook.)"
            end

            super(*args, **kw)
          end
        end
      end
    end
  end
end
