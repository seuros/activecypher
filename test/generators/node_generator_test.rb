# frozen_string_literal: true

require 'test_helper'
require 'rails/generators'
require 'rails/generators/test_case'
require 'active_cypher/generators/node_generator'

class NodeGeneratorTest < Rails::Generators::TestCase
  tests ActiveCypher::Generators::NodeGenerator
  destination File.expand_path('../tmp/generators', __dir__)
  setup :prepare_destination

  test 'generator creates a node file' do
    run_generator ['TestNode']
    assert_file 'app/graph/test_node.rb', /class TestNode < ApplicationGraphNode/
  end

  test 'generator creates a node file with attributes' do
    run_generator ['TestNode', 'name:string', 'age:integer']
    assert_file 'app/graph/test_node.rb' do |content|
      assert_match(/attribute :name, :string/, content)
      assert_match(/attribute :age, :integer/, content)
    end
  end

  test 'generator creates a node file with custom labels' do
    run_generator ['TestNode', '--labels=Custom,Labels']
    assert_file 'app/graph/test_node.rb' do |content|
      assert_match(/label :Custom/, content)
      assert_match(/label :Labels/, content)
    end
  end

  test 'generator handles class collision' do
    # Create a dummy model file
    FileUtils.mkdir_p(File.join(destination_root, 'app/models'))
    model_path = File.join(destination_root, 'app/models/existing_model.rb')
    File.write(model_path, <<~RUBY)
      # frozen_string_literal: true
      class ExistingModel < ApplicationRecord
      end
    RUBY

    # Run the generator with force overwrite
    run_generator(['ExistingModel', '--force'])

    # It should generate the file with --force
    assert_file 'app/graph/existing_model.rb'
  end
end
