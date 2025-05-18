# frozen_string_literal: true

# Default graph fixture profile for tests.
# Add nodes and relationships using the DSL:
#   node :ref, ModelClass, props
#   relationship :ref, :from_ref, :TYPE, :to_ref, props

# Example:
# node :lucy, PersonNode, name: "Lucy", age: 29
# relationship :match, :lucy, :LIKES, :mike, since: 2023

node :john, PersonNode, name: 'John', age: 35
node :max,  PetNode,    name: 'Max', species: 'Dog', age: 3
relationship :owns, :john, :OWNS_PET, :max, since: 2020
