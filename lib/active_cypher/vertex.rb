# frozen_string_literal: true

module ActiveCypher
  ## Vertex
  # A Vertex (also known as a node) represents an entity in the graph. It can be thought of as a point or a data element
  # that contains some properties or attributes.
  # For example, in a social network graph, a node could represent a person, with properties such as name, age, and location.
  #     Type: The type of the vertex, which can be used to group vertices into categories or classes.
  #
  #     Label: A label is an additional attribute that provides a way to group vertices of the same type or class together. Labels can be used to define different sets of properties for different groups of vertices.
  #
  #     Identifier: An identifier is a unique value assigned to each vertex, which can be used to distinguish it from other vertices in the graph.
  #
  #     Properties: Properties are the attributes or characteristics of a vertex. Each property has a name and a value. Properties can be used to store any kind of data, such as strings, numbers, dates, or arrays.
  #
  #     Timestamp: A timestamp is an attribute that stores the date and time when a vertex was created or last modified. This can be useful for tracking changes to the graph over time.
  #
  #     Indexes: Indexes are used to optimize queries and make it faster to search for vertices based on their properties. Indexes can be created on one or more properties of a vertex.
  #
  #     Relationships: A vertex can have relationships with other vertices in the graph. The relationships can be directed or undirected and can have properties of their own.
  class Vertex < Base
    def self.type(type)
      @type = type
    end


  end
end
