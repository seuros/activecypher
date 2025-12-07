# frozen_string_literal: true

require 'test_helper'
# NOTE: Not requiring 'rails_lens' here to avoid ActiveRecord fixture issues
# The extension file provides a stub RailsLens::Extensions::Base when the gem isn't loaded
require 'active_cypher/rails_lens_ext/extension'

module ActiveCypher
  module RailsLensExt
    # Using Minitest::Test directly to avoid ActiveRecord fixture loading
    class AnnotationIntegrationTest < Minitest::Test
      # Test annotation with real dummy app models

      def test_annotates_person_node_from_dummy_app
        extension = Extension.new(PersonNode)
        result = extension.annotate

        refute_nil result
        assert_match(/model_type = "node"/, result)
        assert_match(/labels = \["Person"\]/, result)
        assert_match(/name = "name"/, result)
        assert_match(/type = "string"/, result)
        assert_match(/type = "integer"/, result)
        assert_match(/type = "boolean"/, result)
      end

      def test_annotates_application_graph_node_as_abstract
        extension = Extension.new(ApplicationGraphNode)
        result = extension.annotate

        refute_nil result
        assert_match(/model_type = "node"/, result)
        assert_match(/abstract = true/, result)
        assert_match(/\[connection\]/, result)
        assert_match(/writing = "primary"/, result)
      end

      def test_annotates_enjoys_rel_relationship
        extension = Extension.new(EnjoysRel)
        result = extension.annotate

        refute_nil result
        assert_match(/model_type = "relationship"/, result)
        assert_match(/type = "ENJOYS"/, result)
        assert_match(/from_class = "PersonNode"/, result)
        assert_match(/to_class = "HobbyNode"/, result)
        assert_match(/name = "frequency"/, result)
        assert_match(/type = "date"/, result)
      end

      def test_annotates_company_node
        extension = Extension.new(CompanyNode)
        result = extension.annotate

        refute_nil result
        assert_match(/model_type = "node"/, result)
        assert_match(/labels = \["Company"\]/, result)
      end

      def test_extension_detect_returns_true
        assert Extension.detect?
      end

      def test_extension_is_compatible_with_rails_lens_interface
        assert_respond_to Extension, :gem_name
        assert_respond_to Extension, :detect?
        assert_respond_to Extension, :interface_version
        assert_respond_to Extension, :compatible?

        extension = Extension.new(PersonNode)
        assert_respond_to extension, :annotate
        assert_respond_to extension, :notes
        assert_respond_to extension, :erd_additions
      end

      def test_erd_additions_for_person_node
        extension = Extension.new(PersonNode)
        erd = extension.erd_additions

        assert_includes erd[:badges], 'graph-node'
        assert_equal 'node', erd[:attributes][:model_type]
        assert_includes erd[:attributes][:labels], :Person
      end

      def test_erd_additions_for_enjoys_rel_relationship
        extension = Extension.new(EnjoysRel)
        erd = extension.erd_additions

        assert_includes erd[:badges], 'graph-relationship'
        assert_equal 'relationship', erd[:attributes][:model_type]
        assert_equal 'ENJOYS', erd[:attributes][:relationship_type]

        edge = erd[:relationships].find { |r| r[:type] == 'edge' }
        refute_nil edge
        assert_equal 'PersonNode', edge[:from]
        assert_equal 'HobbyNode', edge[:to]
        assert_equal 'ENJOYS', edge[:label]
      end

      def test_notes_for_person_node_are_empty_valid_model
        extension = Extension.new(PersonNode)
        notes = extension.notes

        # PersonNode is a valid, complete model - no warnings expected
        assert_empty notes
      end

      def test_annotates_multi_label_theory_node_with_multiple_labels
        extension = Extension.new(MultiLabelTheoryNode)
        result = extension.annotate

        refute_nil result
        assert_match(/model_type = "node"/, result)
        # Check for multiple labels in TOML array format
        assert_match(/labels = \[/, result)
      end

    end
  end
end
