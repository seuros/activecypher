# frozen_string_literal: true

require 'test_helper'
require 'rake'
require 'tmpdir'
require_relative 'support/dummy_adapter'

class GraphdbTasksTest < ActiveSupport::TestCase
  def setup
    Rails.application.load_tasks

    # Preserve existing connection handler state so subsequent tests
    # continue using the real database connections.
    @old_handler = ActiveCypher::Base.connection_handler
    @old_mappings = ActiveCypher::Base.connects_to_mappings.dup

    pool = ActiveCypher::ConnectionPool.new(adapter: 'dummy')

    # Replace the handler with a fresh instance that uses the dummy adapter.
    ActiveCypher::Base.instance_variable_set(:@connection_handler, ActiveCypher::ConnectionHandler.new)
    ActiveCypher::Base.connection_handler.set(:primary, pool)
    ActiveCypher::Base.connects_to_mappings = { writing: :primary, reading: :primary }
  end

  def teardown
    # Restore the original handler and mappings so other tests see the
    # correct real database connections.
    ActiveCypher::Base.instance_variable_set(:@connection_handler, @old_handler)
    ActiveCypher::Base.connects_to_mappings = @old_mappings

    Rake::Task['graphdb:migrate'].reenable
    Rake::Task['graphdb:status'].reenable
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
