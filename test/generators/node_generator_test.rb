# frozen_string_literal: true

require 'test_helper'
require 'rails/generators'
require 'rails/generators/test_case'
require 'active_cypher/generators/node_generator'

class NodeGeneratorTest < Rails::Generators::TestCase
  tests ActiveCypher::Generators::NodeGenerator
  destination File.expand_path('../tmp/generators', __dir__)

  setup do
    prepare_destination
    graph_dir = File.expand_path('../../app/graph', __dir__)
    FileUtils.rm_rf(graph_dir) if Dir.exist?(graph_dir)
    FileUtils.mkdir_p(graph_dir)
  end

  test 'generator creates a node file with Node suffix if missing' do
    run_generator ['Galaxy']
    assert_file 'app/graph/galaxy_node.rb', /class GalaxyNode < ApplicationGraphNode/
  end

  test 'generator creates a namespaced node file' do
    run_generator(['SpaceShip::MetricNode'])
    assert_file 'app/graph/space_ship/metric_node.rb', /class SpaceShip::MetricNode < ApplicationGraphNode/
  end

  test 'generator does not double Node suffix' do
    run_generator ['AnomalyNode']
    assert_file 'app/graph/anomaly_node.rb', /class AnomalyNode < ApplicationGraphNode/
  end

  test 'generator creates a node file with custom suffix' do
    run_generator ['Widget', '--suffix=Vertex']
    assert_file 'app/graph/widget_vertex.rb', /class WidgetVertex < ApplicationGraphNode/
  end

  test 'generator does not double custom suffix' do
    run_generator ['WidgetVertex', '--suffix=Vertex']
    assert_file 'app/graph/widget_vertex.rb', /class WidgetVertex < ApplicationGraphNode/
  end

  test 'generator creates a node file with attributes' do
    run_generator ['Planet']
    assert_file 'app/graph/planet_node.rb', /class PlanetNode < ApplicationGraphNode/
    run_generator ['Planet', 'name:string', 'mass:float']
    assert_file 'app/graph/planet_node.rb' do |content|
      assert_match(/attribute :name, :string/, content)
      assert_match(/attribute :mass, :float/, content)
    end
    run_generator ['Planet', 'name:string', 'mass:float', '--suffix=Vertex']
    assert_file 'app/graph/planet_vertex.rb' do |content|
      assert_match(/attribute :name, :string/, content)
      assert_match(/attribute :mass, :float/, content)
    end
  end

  test 'generator creates a node file with custom labels' do
    run_generator ['LabelTest', '--labels=Custom,Labels']
    assert_file 'app/graph/label_test_node.rb' do |content|
      assert_match(/label :Custom/, content)
      assert_match(/label :Labels/, content)
    end

    run_generator ['LabelTest', '--labels=Custom,Labels', '--suffix=Vertex']
    assert_file 'app/graph/label_test_vertex.rb' do |content|
      assert_match(/label :Custom/, content)
      assert_match(/label :Labels/, content)
    end
  end

  test 'generator handles class collision for both base and Node-suffixed names' do
    # Create a dummy model file for base name
    FileUtils.mkdir_p(File.join(destination_root, 'app/models'))
    model_path = File.join(destination_root, 'app/models/existing_model.rb')
    File.write(model_path, <<~RUBY)
      # frozen_string_literal: true
      class ExistingModel < ApplicationRecord
      end
    RUBY

    # Run the generator with force overwrite for base name
    run_generator(['ExistingModel', '--force'])
    assert_file 'app/graph/existing_model_node.rb'

    # Create a dummy model file for Node-suffixed name
    model_path2 = File.join(destination_root, 'app/models/existing_node.rb')
    File.write(model_path2, <<~RUBY)
      # frozen_string_literal: true
      class ExistingNode < ApplicationRecord
      end
    RUBY

    # Run the generator with force overwrite for Node-suffixed name
    run_generator(['ExistingNode', '--force'])
    assert_file 'app/graph/existing_node.rb'
  end

  test 'generator handles class collision with custom suffix at runtime' do
    FileUtils.mkdir_p(File.join(destination_root, 'app/models'))
    model_path = File.join(destination_root, 'app/models/custom_vertex.rb')
    File.write(model_path, <<~RUBY)
      # frozen_string_literal: true
      class CustomVertex < ApplicationRecord
      end
    RUBY

    # Should generate CustomVertex in app/graph/custom_vertex.rb
    run_generator(['Custom', '--suffix=Vertex', '--force'])
    assert_file 'app/graph/custom_vertex.rb'
  end
end
