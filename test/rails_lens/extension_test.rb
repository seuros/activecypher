# frozen_string_literal: true

require 'test_helper'
# NOTE: Not requiring 'rails_lens' here to avoid ActiveRecord fixture issues
# The extension file provides a stub RailsLens::Extensions::Base when the gem isn't loaded
require 'active_cypher/rails_lens_ext/extension'

module ActiveCypher
  module RailsLensExt
    class ExtensionTest < ActiveSupport::TestCase
      # ============================================================
      # Test Node Classes
      # All test classes are marked abstract to prevent fixture system interference
      # ============================================================

      class TestAbstractNode < ActiveCypher::Base
        self.abstract_class = true
      end

      class TestPersonNode < ActiveCypher::Base
        self.abstract_class = true # Prevent fixture system from loading
        label :Person
        attribute :name, :string
        attribute :age, :integer
      end

      class TestMultiLabelNode < ActiveCypher::Base
        self.abstract_class = true # Prevent fixture system from loading
        label :Actor
        label :Director
        attribute :name, :string
      end

      class TestNodeWithAssociations < ActiveCypher::Base
        self.abstract_class = true # Prevent fixture system from loading
        include ActiveCypher::Associations

        label :Author

        attribute :name, :string

        has_many :books, class_name: 'TestBookNode', relationship: 'WROTE', direction: :out
        belongs_to :publisher, class_name: 'TestPublisherNode', relationship: 'PUBLISHED_BY'
        has_one :profile, class_name: 'TestProfileNode', relationship: 'HAS_PROFILE'
      end

      # ============================================================
      # Test Relationship Classes
      # ============================================================

      class TestAbstractRelationship < ActiveCypher::Relationship
        self.abstract_class = true
      end

      class TestWorksAtRelationship < ActiveCypher::Relationship
        self.abstract_class = true # Prevent fixture system from loading
        from_class 'TestPersonNode'
        to_class   'TestCompanyNode'
        type       'WORKS_AT'

        attribute :title, :string
        attribute :since, :integer
      end

      class TestIncompleteRelationship < ActiveCypher::Relationship
        self.abstract_class = true # Prevent fixture system from loading
        # Missing from_class, to_class, and type
        attribute :note, :string
      end

      # ============================================================
      # Class Method Tests
      # ============================================================

      test 'gem_name returns activecypher' do
        assert_equal 'activecypher', Extension.gem_name
      end

      test 'detect? returns true when activecypher is available' do
        assert_predicate Extension, :detect?
      end

      test 'interface_version is 1.0' do
        assert_equal '1.0', Extension.interface_version
      end

      # ============================================================
      # Node Annotation Tests
      # ============================================================

      test 'annotate returns nil for non-activecypher models' do
        # Create a plain Ruby class
        plain_class = Class.new
        extension = Extension.new(plain_class)

        assert_nil extension.annotate
      end

      test 'annotate generates node annotation for simple node in TOML format' do
        extension = Extension.new(TestPersonNode)
        result = extension.annotate

        assert_match(/model_type = "node"/, result)
        assert_match(/labels = \["Person"\]/, result)
        assert_match(/attributes = \[/, result)
        assert_match(/name = "name"/, result)
        assert_match(/type = "string"/, result)
        assert_match(/type = "integer"/, result)
      end

      test 'annotate includes abstract flag for abstract nodes' do
        extension = Extension.new(TestAbstractNode)
        result = extension.annotate

        assert_match(/model_type = "node"/, result)
        assert_match(/abstract = true/, result)
      end

      test 'annotate handles multiple labels in TOML array format' do
        extension = Extension.new(TestMultiLabelNode)
        result = extension.annotate

        assert_match(/labels = \["Actor", "Director"\]/, result)
      end

      test 'annotate includes associations in TOML format' do
        extension = Extension.new(TestNodeWithAssociations)
        result = extension.annotate

        assert_match(/\[associations\]/, result)
        assert_match(/books = \{/, result)
        assert_match(/macro = "has_many"/, result)
        assert_match(/publisher = \{/, result)
        assert_match(/macro = "belongs_to"/, result)
        assert_match(/profile = \{/, result)
        assert_match(/macro = "has_one"/, result)
        assert_match(/rel = "WROTE"/, result)
      end

      # ============================================================
      # Relationship Annotation Tests
      # ============================================================

      test 'annotate generates relationship annotation in TOML format' do
        extension = Extension.new(TestWorksAtRelationship)
        result = extension.annotate

        assert_match(/model_type = "relationship"/, result)
        assert_match(/type = "WORKS_AT"/, result)
        assert_match(/from_class = "TestPersonNode"/, result)
        assert_match(/to_class = "TestCompanyNode"/, result)
        assert_match(/attributes = \[/, result)
        assert_match(/name = "title"/, result)
        assert_match(/name = "since"/, result)
      end

      test 'annotate includes abstract flag for abstract relationships' do
        extension = Extension.new(TestAbstractRelationship)
        result = extension.annotate

        assert_match(/model_type = "relationship"/, result)
        assert_match(/abstract = true/, result)
      end

      # ============================================================
      # Notes Tests
      # ============================================================

      test 'notes returns empty array for non-activecypher models' do
        plain_class = Class.new
        extension = Extension.new(plain_class)

        assert_empty extension.notes
      end

      test 'notes warns about incomplete relationships' do
        # Create a non-abstract incomplete relationship for testing notes
        incomplete_rel = Class.new(ActiveCypher::Relationship) do
          # NOT setting abstract_class = true
          # Missing from_class, to_class, and type
          attribute :note, :string
        end

        extension = Extension.new(incomplete_rel)
        notes = extension.notes

        assert(notes.any? { |n| n.include?('Missing from_class') })
        assert(notes.any? { |n| n.include?('Missing to_class') })
        assert(notes.any? { |n| n.include?('Missing relationship type') })
      end

      # ============================================================
      # ERD Additions Tests
      # ============================================================

      test 'erd_additions returns default for non-activecypher models' do
        plain_class = Class.new
        extension = Extension.new(plain_class)
        result = extension.erd_additions

        assert_empty result[:relationships]
        assert_empty result[:badges]
        assert_empty result[:attributes]
      end

      test 'erd_additions returns node data for nodes' do
        extension = Extension.new(TestPersonNode)
        result = extension.erd_additions

        assert_includes result[:badges], 'graph-node'
        assert_equal 'node', result[:attributes][:model_type]
        assert_includes result[:attributes][:labels], :Person
      end

      test 'erd_additions returns relationship data for relationships' do
        extension = Extension.new(TestWorksAtRelationship)
        result = extension.erd_additions

        assert_includes result[:badges], 'graph-relationship'
        assert_equal 'relationship', result[:attributes][:model_type]
        assert_equal 'WORKS_AT', result[:attributes][:relationship_type]

        # Check edge relationship
        edge = result[:relationships].find { |r| r[:type] == 'edge' }
        assert_not_nil edge
        assert_equal 'TestPersonNode', edge[:from]
        assert_equal 'TestCompanyNode', edge[:to]
      end

      test 'erd_additions includes abstract badge for abstract classes' do
        extension = Extension.new(TestAbstractNode)
        result = extension.erd_additions

        assert_includes result[:badges], 'abstract'
      end

      test 'erd_additions includes association relationships' do
        extension = Extension.new(TestNodeWithAssociations)
        result = extension.erd_additions

        wrote_rel = result[:relationships].find { |r| r[:label] == 'WROTE' }
        assert_not_nil wrote_rel
        assert_equal 'has_many', wrote_rel[:type]
        assert_match(/TestNodeWithAssociations\z/, wrote_rel[:from])
        assert_equal 'TestBookNode', wrote_rel[:to]
      end
    end
  end
end
