# frozen_string_literal: true

module ActiveCypher
  module Schema
    module Writer
      class Cypher
        def initialize(catalog, vendor)
          @catalog = catalog
          @vendor  = vendor
        end

        def to_s
          sections = []
          sections << constraint_lines(@catalog.constraints)
          sections << index_lines(@catalog.indexes.select { |i| i.element == :node }, :node)
          sections << index_lines(@catalog.indexes.select { |i| i.element == :relationship }, :relationship)
          if @vendor == :memgraph
            sections << node_type_lines(@catalog.node_types)
            sections << edge_type_lines(@catalog.edge_types)
          end
          sections.reject(&:empty?).join("\n")
        end

        private

        def constraint_lines(list)
          list.sort_by(&:name).map do |c|
            props = c.props.map { |p| "n.#{p}" }.join(', ')
            case c.kind
            when :unique
              "CREATE CONSTRAINT #{c.name} FOR (n:`#{c.label}`) REQUIRE (#{props}) IS UNIQUE"
            when :exists
              "CREATE CONSTRAINT #{c.name} FOR (n:`#{c.label}`) REQUIRE n.#{c.props.first} IS NOT NULL"
            else
              "-- UNKNOWN CONSTRAINT #{c.name}"
            end
          end.join("\n")
        end

        def index_lines(list, element)
          list.sort_by(&:name).map do |i|
            if @vendor == :memgraph && i.vector_opts
              "-- NOT-SUPPORTED ON MEMGRAPH 3.2: Vector index #{i.name}"
            else
              var = element == :node ? 'n' : 'r'
              target = element == :node ? "(#{var}:`#{i.label}`)" : "()-[#{var}:`#{i.label}`]-()"
              props = i.props.map { |p| "#{var}.#{p}" }.join(', ')
              line = +'CREATE '
              line << 'UNIQUE ' if i.unique
              line << "INDEX #{i.name} FOR #{target} ON (#{props})"
              if i.vector_opts && @vendor == :neo4j
                opts = i.vector_opts.map { |k, v| "#{k}: #{v}" }.join(', ')
                line << " OPTIONS { #{opts} }"
              end
              line
            end
          end.join("\n")
        end

        def node_type_lines(list)
          list.sort_by(&:label).map do |nt|
            props = nt.props.join(', ')
            pk = nt.primary_key ? " PRIMARY KEY #{nt.primary_key}" : ''
            "CREATE NODE TYPE #{nt.label}#{pk} PROPERTIES #{props}"
          end.join("\n")
        end

        def edge_type_lines(list)
          list.sort_by(&:type).map do |et|
            props = et.props.join(', ')
            "CREATE EDGE TYPE #{et.type} FROM #{et.from} TO #{et.to} PROPERTIES #{props}"
          end.join("\n")
        end
      end
    end
  end
end
