# frozen_string_literal: true

module TestGenerators
  Literal =
    G.tree(G.integer) do |subtree_gen|
      G.one_of(
        G.nil,
        G.boolean,
        G.integer,
        G.float,
        G.printable_string,
        G.array(subtree_gen, max: 4),
        G.hash_of(G.string, subtree_gen, max: 4)
      )
    end
end
