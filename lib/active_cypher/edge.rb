# frozen_string_literal: true

module ActiveCypher
  # An edge (also known as a relationship or an arc) represents a connection between two nodes in the graph.
  # It can be thought of as a line or a directed link between two nodes, indicating some kind of relationship or interaction between them.
  # For example, in a social network graph, an edge could represent a friendship or a follow relationship between two people.
  # Edges can also have properties or attributes, which describe the relationship between the two nodes it connects.
  class Edge < Base
    def self.from_class(from_class)
      @from_class = from_class
    end

    def self.to_class(to_class)
      @to_class = to_class
    end

    def self.type(type)
      @type = type
    end


    def to_cypher
      "CREATE (#{from_cypher})-[#{edge_cypher}]->(#{to_cypher})"
    end
  end
end
