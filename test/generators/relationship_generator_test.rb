# frozen_string_literal: true

require 'test_helper'
require 'rails/generators'
require 'rails/generators/test_case'
require 'active_cypher/generators/relationship_generator'

class RelationshipGeneratorTest < Rails::Generators::TestCase
  tests ActiveCypher::Generators::RelationshipGenerator
  destination File.expand_path('../tmp/generators', __dir__)
  setup :prepare_destination

  test 'generator creates a relationship file' do
    run_generator ['TestRelationship', '--from=SourceNode', '--to=TargetNode']
    assert_file 'app/graph/test_relationship.rb', /class TestRelationship < ApplicationGraphRelationship/
  end

  test 'generator creates a relationship file with attributes' do
    run_generator ['TestRelationship', 'since:datetime', 'active:boolean', '--from=SourceNode', '--to=TargetNode']
    assert_file 'app/graph/test_relationship.rb' do |content|
      assert_match(/attribute :since, :datetime/, content)
      assert_match(/attribute :active, :boolean/, content)
    end
  end

  test 'generator creates a relationship file with custom type' do
    run_generator ['TestRelationship', '--from=SourceNode', '--to=TargetNode', '--type=CUSTOM_TYPE']
    assert_file 'app/graph/test_relationship.rb' do |content|
      assert_match(/type\s+:CUSTOM_TYPE/, content)
    end
  end

  test 'generator handles class collision' do
    # Create a dummy model file
    FileUtils.mkdir_p(File.join(destination_root, 'app/models'))
    model_path = File.join(destination_root, 'app/models/existing_relation.rb')
    File.write(model_path, <<~RUBY)
      # frozen_string_literal: true
      class ExistingRelation < ApplicationRecord
      end
    RUBY

    # Run the generator with force overwrite
    run_generator(['ExistingRelation', '--from=SourceNode', '--to=TargetNode', '--force'])

    # It should generate the file with --force
    assert_file 'app/graph/existing_relation.rb'
  end
end
