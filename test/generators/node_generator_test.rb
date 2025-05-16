# frozen_string_literal: true

require 'test_helper'
require 'rails/generators'
require 'rails/generators/test_case'
require 'active_cypher/generators/node_generator'

class NodeGeneratorTest < Rails::Generators::TestCase
  tests ActiveCypher::Generators::NodeGenerator
  destination File.expand_path('../tmp/generators', __dir__)

  # Run before each test
  setup do
    prepare_destination
    cleanup_graph_directory
  end

  # Run after each test
  teardown do
    cleanup_graph_directory
  end

  private

  def cleanup_graph_directory
    # Clean up destination graph directory
    dest_graph_dir = File.join(destination_root, 'app/graph')
    FileUtils.rm_rf(dest_graph_dir)
    FileUtils.mkdir_p(dest_graph_dir)

    # Clean up app/models directory to avoid class collision issues
    models_dir = File.join(destination_root, 'app/models')
    FileUtils.rm_rf(models_dir)
    FileUtils.mkdir_p(models_dir)
  end

  # Run generator with better error handling
  def safe_run_generator(args)
    run_generator(args)
  rescue StandardError => e
    puts "Error running generator with args #{args.inspect}: #{e.message}"
    raise
  end

  test 'generator creates a node file with Node suffix if missing' do
    safe_run_generator(['Galaxy'])
    assert_file 'app/graph/galaxy_node.rb', /class GalaxyNode < ApplicationGraphNode/
  end

  test 'generator creates a namespaced node file' do
    safe_run_generator(['SpaceShip::MetricNode'])
    assert_file 'app/graph/space_ship/metric_node.rb', /class SpaceShip::MetricNode < ApplicationGraphNode/
  end

  test 'generator does not double Node suffix' do
    safe_run_generator(['AnomalyNode'])
    assert_file 'app/graph/anomaly_node.rb', /class AnomalyNode < ApplicationGraphNode/
  end

  test 'generator creates a node file with custom suffix' do
    safe_run_generator(['Widget', '--suffix=Vertex'])
    assert_file 'app/graph/widget_vertex.rb', /class WidgetVertex < ApplicationGraphNode/
  end

  test 'generator does not double custom suffix' do
    safe_run_generator(['WidgetVertex', '--suffix=Vertex'])
    assert_file 'app/graph/widget_vertex.rb', /class WidgetVertex < ApplicationGraphNode/
  end

  test 'generator creates a simple node file' do
    safe_run_generator(['Planet'])
    assert_file 'app/graph/planet_node.rb', /class PlanetNode < ApplicationGraphNode/
  end

  test 'generator creates a node file with attributes' do
    safe_run_generator(['Mars', 'name:string', 'mass:float'])
    assert_file 'app/graph/mars_node.rb' do |content|
      assert_match(/attribute :name, :string/, content)
      assert_match(/attribute :mass, :float/, content)
    end
  end

  test 'generator creates a node file with custom suffix and attributes' do
    safe_run_generator(['Jupiter', 'name:string', 'mass:float', '--suffix=Vertex'])
    assert_file 'app/graph/jupiter_vertex.rb' do |content|
      assert_match(/attribute :name, :string/, content)
      assert_match(/attribute :mass, :float/, content)
    end
  end

  test 'generator creates a node file with custom labels' do
    safe_run_generator(['LabelTest', '--labels=Custom,Labels'])
    assert_file 'app/graph/label_test_node.rb' do |content|
      assert_match(/label :Custom/, content)
      assert_match(/label :Labels/, content)
    end
  end

  test 'generator creates a node file with custom suffix and labels' do
    safe_run_generator(['LabelTest2', '--labels=Custom,Labels', '--suffix=Vertex'])
    assert_file 'app/graph/label_test2_vertex.rb' do |content|
      assert_match(/label :Custom/, content)
      assert_match(/label :Labels/, content)
    end
  end

  test 'generator handles class collision for base name' do
    # Create a dummy model file for base name
    FileUtils.mkdir_p(File.join(destination_root, 'app/models'))
    model_path = File.join(destination_root, 'app/models/existing_model.rb')
    File.write(model_path, <<~RUBY)
      # frozen_string_literal: true
      class ExistingModel < ApplicationRecord
      end
    RUBY

    # Run the generator with force overwrite for base name
    safe_run_generator(['ExistingModel', '--force'])
    assert_file 'app/graph/existing_model_node.rb'
  end

  test 'generator handles class collision for Node-suffixed name' do
    # Create a dummy model file for Node-suffixed name
    FileUtils.mkdir_p(File.join(destination_root, 'app/models'))
    model_path = File.join(destination_root, 'app/models/existing_node.rb')
    File.write(model_path, <<~RUBY)
      # frozen_string_literal: true
      class ExistingNode < ApplicationRecord
      end
    RUBY

    # Run the generator with force overwrite for Node-suffixed name
    safe_run_generator(['ExistingNode', '--force'])
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
    safe_run_generator(['Custom', '--suffix=Vertex', '--force'])
    assert_file 'app/graph/custom_vertex.rb'
  end
end
