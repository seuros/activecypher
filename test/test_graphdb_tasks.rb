require 'test_helper'
require 'rake'
require 'tmpdir'

class GraphdbTasksTest < ActiveSupport::TestCase
  class DummyAdapter < ActiveCypher::ConnectionAdapters::AbstractAdapter
    attr_reader :executed

    def initialize(config = {})
      super
      @executed = []
      @connected = false
    end

    def connect
      @connected = true
    end

    def active?
      @connected
    end

    def execute_cypher(cypher, _params = {}, _ctx = 'Query')
      @executed << cypher.strip
      []
    end
  end

  def setup
    Rails.application.load_tasks
    ActiveCypher::ConnectionAdapters.const_set('DummyAdapter', DummyAdapter) unless ActiveCypher::ConnectionAdapters.const_defined?('DummyAdapter')
    pool = ActiveCypher::ConnectionPool.new(adapter: 'dummy')
    ActiveCypher::Base.connection_handler.set(:primary, pool)
    ActiveCypher::Base.connects_to_mappings = { writing: :primary, reading: :primary }
  end

  def teardown
    Rake::Task['graphdb:migrate'].reenable if Rake::Task.task_defined?('graphdb:migrate')
    Rake::Task['graphdb:status'].reenable if Rake::Task.task_defined?('graphdb:status')
    if ActiveCypher::ConnectionAdapters.const_defined?('DummyAdapter')
      ActiveCypher::ConnectionAdapters.send(:remove_const, 'DummyAdapter')
    end
  end

  def write_migration(dir, version, name, content)
    path = File.join(dir, 'graphdb', 'migrate')
    FileUtils.mkdir_p(path)
    File.write(File.join(path, "#{version}_#{name}.rb"), content)
  end

  test 'graphdb rake tasks exist' do
    assert Rake::Task.task_defined?('graphdb:migrate')
    assert Rake::Task.task_defined?('graphdb:status')
  end

  test 'graphdb tasks run using default connection' do
    Dir.mktmpdir do |dir|
      write_migration(dir, '20250521113035', 'add_node', <<~RUBY)
        class AddNode < ActiveCypher::Migration
          up { execute 'CREATE (n:Test)' }
        end
      RUBY

      Dir.chdir(dir) do
        out_status = capture_io { Rake::Task['graphdb:status'].invoke }.first
        assert_match(/down\s+20250521113035/, out_status)
        Rake::Task['graphdb:status'].reenable
        out_migrate = capture_io { Rake::Task['graphdb:migrate'].invoke }.first
        assert_includes out_migrate, 'GraphDB migrations complete'
      end
    end
  end
end
