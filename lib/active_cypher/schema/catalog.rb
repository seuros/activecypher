# frozen_string_literal: true

module ActiveCypher
  module Schema
    IndexDef      = Data.define(:name, :element, :label, :props, :unique, :vector_opts)
    ConstraintDef = Data.define(:name, :label, :props, :kind)
    NodeTypeDef   = Data.define(:label, :props, :primary_key)
    EdgeTypeDef   = Data.define(:type, :from, :to, :props)

    Catalog = Data.define(:indexes, :constraints, :node_types, :edge_types) do
      def empty?
        indexes.empty? && constraints.empty? && node_types.empty? && edge_types.empty?
      end
    end
  end
end
