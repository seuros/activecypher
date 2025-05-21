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
    run_generator ['Alliance', '--from=SpaceShipNode', '--to=PlanetNode']
    assert_file 'app/graph/alliance_rel.rb' do |content|
      assert_match(/class AllianceRel < ApplicationGraphRelationship/, content)
      assert_match(/from_class 'SpaceShipNode'/, content)
      assert_match(/to_class   'PlanetNode'/, content)
    end
  end

  test 'generator creates a relationship file with attributes' do
    run_generator ['Encounter', 'date:datetime', 'location:string', '--from=SpaceShipNode', '--to=AnomalyNode']
    assert_file 'app/graph/encounter_rel.rb' do |content|
      assert_match(/attribute :date, :datetime/, content)
      assert_match(/attribute :location, :string/, content)
    end
  end

  test 'generator creates a relationship file with custom type' do
    run_generator ['Discovery', '--from=SpaceShipNode', '--to=PlanetNode', '--type=FIRST_CONTACT']
    assert_file 'app/graph/discovery_rel.rb' do |content|
      assert_match(/type\s+'FIRST_CONTACT'/, content)
    end
  end

  test 'generator creates a relationship file with custom suffix' do
    run_generator ['Trade', '--from=SpaceShipNode', '--to=PlanetNode', '--suffix=Edge']
    assert_file 'app/graph/trade_edge.rb', /class TradeEdge < ApplicationGraphRelationship/
  end

  test 'generator does not double custom suffix' do
    run_generator ['TradeEdge', '--from=SpaceShipNode', '--to=PlanetNode', '--suffix=Edge']
    assert_file 'app/graph/trade_edge.rb', /class TradeEdge < ApplicationGraphRelationship/
  end

  test 'generator creates a namespaced relationship file' do
    run_generator ['Federation::Treaty', '--from=SpaceShipNode', '--to=PlanetNode']
    assert_file 'app/graph/federation/treaty_rel.rb', /class Federation::TreatyRel < ApplicationGraphRelationship/
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
    run_generator(['ExistingRelation', '--from=SpaceShipNode', '--to=PlanetNode', '--force'])

    # It should generate the file with --force
    assert_file 'app/graph/existing_relation_rel.rb'
  end
end
