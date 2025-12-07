# frozen_string_literal: true

# RailsLens extension for ActiveCypher graph models
# Provides annotation support for Node and Relationship classes
#
# This extension detects ActiveCypher models and generates annotations
# including labels, attributes, associations, and relationship metadata.

begin
  require 'rails_lens/extensions/base'
rescue LoadError
  # RailsLens not available - define a stub Base class
  module RailsLens
    module Extensions
      class Base
        INTERFACE_VERSION = '1.0'

        class << self
          def gem_name = raise(NotImplementedError)
          def detect? = raise(NotImplementedError)
          def interface_version = INTERFACE_VERSION
          def compatible? = true

          def gem_available?(name)
            Gem::Specification.find_by_name(name)
            true
          rescue Gem::LoadError
            false
          end
        end

        attr_reader :model_class

        def initialize(model_class)
          @model_class = model_class
        end

        def annotate = nil
        def notes = []
        def erd_additions = { relationships: [], badges: [], attributes: {} }
      end
    end
  end
end

module ActiveCypher
  # RailsLens extension module for annotating ActiveCypher graph models
  #
  # Detects and annotates:
  # - Node classes (inheriting from ActiveCypher::Base)
  # - Relationship classes (inheriting from ActiveCypher::Relationship)
  #
  # Generates annotations for:
  # - Graph labels
  # - Attributes with types
  # - Associations (has_many, belongs_to, has_one)
  # - Relationship endpoints and types
  # - Connection configuration
  module RailsLensExt
    class Extension < ::RailsLens::Extensions::Base
      INTERFACE_VERSION = '1.0'

      class << self
        def gem_name
          'activecypher'
        end

        def detect?
          return false unless gem_available?(gem_name)

          # Ensure ActiveCypher is loaded
          require 'activecypher' unless defined?(::ActiveCypher::Base)
          true
        rescue LoadError
          false
        end
      end

      # Generate annotation string for ActiveCypher models
      def annotate
        return nil unless active_cypher_model?

        lines = []

        if node_class?
          lines.concat(node_annotation_lines)
        elsif relationship_class?
          lines.concat(relationship_annotation_lines)
        end

        return nil if lines.empty?

        lines.join("\n")
      end

      # Generate analysis notes for best practices
      def notes
        return [] unless active_cypher_model?

        notes = []

        if node_class?
          notes.concat(node_notes)
        elsif relationship_class?
          notes.concat(relationship_notes)
        end

        notes
      end

      # Generate ERD additions for graph visualization
      def erd_additions
        return default_erd_additions unless active_cypher_model?

        if node_class?
          node_erd_additions
        elsif relationship_class?
          relationship_erd_additions
        else
          default_erd_additions
        end
      end

      private

      def default_erd_additions
        { relationships: [], badges: [], attributes: {} }
      end

      # ============================================================
      # Detection Methods
      # ============================================================

      def active_cypher_model?
        node_class? || relationship_class?
      end

      def node_class?
        return false unless defined?(::ActiveCypher::Base)

        model_class < ::ActiveCypher::Base
      rescue StandardError
        false
      end

      def relationship_class?
        return false unless defined?(::ActiveCypher::Relationship)

        model_class < ::ActiveCypher::Relationship
      rescue StandardError
        false
      end

      def abstract_class?
        model_class.respond_to?(:abstract_class?) && model_class.abstract_class?
      end

      # ============================================================
      # Node Annotation (TOML format)
      # ============================================================

      def node_annotation_lines
        lines = []
        lines << 'model_type = "node"'
        lines << 'abstract = true' if abstract_class?

        # Labels
        if model_class.respond_to?(:labels) && model_class.labels.any?
          labels = model_class.labels.map { |l| "\"#{l}\"" }.join(', ')
          lines << "labels = [#{labels}]"
        end

        # Attributes
        lines.concat(attribute_lines)

        # Associations
        lines.concat(association_lines) if model_class.respond_to?(:_reflections)

        # Connection info
        lines.concat(connection_lines)

        lines
      end

      # ============================================================
      # Relationship Annotation (TOML format)
      # ============================================================

      def relationship_annotation_lines
        lines = []
        lines << 'model_type = "relationship"'
        lines << 'abstract = true' if abstract_class?

        # Relationship type
        lines << "type = \"#{model_class.relationship_type}\"" if model_class.respond_to?(:relationship_type) && model_class.relationship_type

        # Endpoints
        lines << "from_class = \"#{model_class.from_class_name}\"" if model_class.respond_to?(:from_class_name) && model_class.from_class_name

        lines << "to_class = \"#{model_class.to_class_name}\"" if model_class.respond_to?(:to_class_name) && model_class.to_class_name

        # Node base class (for connection delegation)
        lines << "node_base_class = \"#{model_class._node_base_class.name}\"" if model_class.respond_to?(:node_base_class) && model_class._node_base_class

        # Attributes
        lines.concat(attribute_lines)

        # Connection info
        lines.concat(connection_lines)

        lines
      end

      # ============================================================
      # Shared Annotation Helpers (TOML format)
      # ============================================================

      def attribute_lines
        lines = []

        return lines unless model_class.respond_to?(:attribute_types)

        attrs = model_class.attribute_types.except('internal_id')
        return lines if attrs.empty?

        lines << ''
        attr_entries = attrs.map do |name, type|
          type_name = type.class.name.demodulize.underscore.sub(/_type$/, '')
          "{ name = \"#{name}\", type = \"#{type_name}\" }"
        end
        lines << "attributes = [#{attr_entries.join(', ')}]"

        lines
      end

      def association_lines
        lines = []
        reflections = model_class._reflections

        return lines if reflections.empty?

        lines << ''
        lines << '[associations]'

        reflections.each do |name, opts|
          macro = opts[:macro]
          target = opts[:class_name]
          rel_type = opts[:relationship]
          direction = opts[:direction]

          parts = ["macro = \"#{macro}\""]
          parts << "class = \"#{target}\"" if target
          parts << "rel = \"#{rel_type}\"" if rel_type
          parts << "direction = \"#{direction}\"" if direction && direction != :out

          if opts[:through]
            parts << "through = \"#{opts[:through]}\""
            parts << "source = \"#{opts[:source]}\"" if opts[:source]
          end

          parts << "relationship_class = \"#{opts[:relationship_class]}\"" if opts[:relationship_class]

          lines << "#{name} = { #{parts.join(', ')} }"
        end

        lines
      end

      def connection_lines
        lines = []

        return lines unless model_class.respond_to?(:connects_to_mappings)

        mappings = model_class.connects_to_mappings
        return lines if mappings.nil? || mappings.empty?

        lines << ''
        lines << '[connection]'

        mappings.each do |role, db_key|
          lines << "#{role} = \"#{db_key}\""
        end

        lines
      end

      # ============================================================
      # Node Notes (Best Practices)
      # ============================================================

      def node_notes
        notes = []

        # Check for missing labels
        notes << "[activecypher] #{model_class.name}: No labels defined" if model_class.respond_to?(:labels) && model_class.labels.empty?

        # Check for models without attributes (besides internal_id)
        if model_class.respond_to?(:attribute_types)
          user_attrs = model_class.attribute_types.except('internal_id')
          notes << "[activecypher] #{model_class.name}: No attributes defined" if user_attrs.empty? && !abstract_class?
        end

        # Check for potential N+1 patterns in associations
        if model_class.respond_to?(:_reflections)
          has_many_count = model_class._reflections.count { |_, r| r[:macro] == :has_many }
          notes << "[activecypher] #{model_class.name}: #{has_many_count} has_many associations - consider eager loading" if has_many_count > 3
        end

        notes
      end

      # ============================================================
      # Relationship Notes (Best Practices)
      # ============================================================

      def relationship_notes
        notes = []

        # Check for missing endpoints
        unless abstract_class?
          if !model_class.respond_to?(:from_class_name) || model_class.from_class_name.nil?
            notes << "[activecypher] #{model_class.name}: Missing from_class definition"
          end

          if !model_class.respond_to?(:to_class_name) || model_class.to_class_name.nil?
            notes << "[activecypher] #{model_class.name}: Missing to_class definition"
          end

          if !model_class.respond_to?(:relationship_type) || model_class.relationship_type.nil?
            notes << "[activecypher] #{model_class.name}: Missing relationship type definition"
          end
        end

        notes
      end

      # ============================================================
      # ERD Additions
      # ============================================================

      def node_erd_additions
        badges = ['graph-node']
        badges << 'abstract' if abstract_class?

        relationships = []

        # Add relationships from associations
        if model_class.respond_to?(:_reflections)
          model_class._reflections.each_value do |opts|
            rel = {
              type: opts[:macro].to_s,
              from: model_class.name,
              to: opts[:class_name],
              label: opts[:relationship],
              style: opts[:macro] == :has_many ? 'solid' : 'dashed',
              direction: opts[:direction]
            }
            relationships << rel
          end
        end

        {
          relationships: relationships,
          badges: badges,
          attributes: {
            model_type: 'node',
            labels: model_class.respond_to?(:labels) ? model_class.labels : []
          }
        }
      end

      def relationship_erd_additions
        badges = ['graph-relationship']
        badges << 'abstract' if abstract_class?

        relationships = []

        # Add the relationship edge
        if model_class.respond_to?(:from_class_name) &&
           model_class.respond_to?(:to_class_name) &&
           model_class.from_class_name &&
           model_class.to_class_name

          relationships << {
            type: 'edge',
            from: model_class.from_class_name,
            to: model_class.to_class_name,
            label: model_class.relationship_type || 'RELATED',
            style: 'bold',
            model: model_class.name
          }
        end

        {
          relationships: relationships,
          badges: badges,
          attributes: {
            model_type: 'relationship',
            relationship_type: model_class.respond_to?(:relationship_type) ? model_class.relationship_type : nil
          }
        }
      end
    end
  end

  # Register the extension with RailsLens for gem-based auto-discovery
  # RailsLens looks for GemName::RailsLensExtension constant
  RailsLensExtension = RailsLensExt::Extension
end
