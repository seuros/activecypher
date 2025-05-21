# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require_relative 'support/dummy_adapter'

class MigratorTest < ActiveSupport::TestCase
  def setup
    @tmp = Dir.mktmpdir
    @graphdb = File.join(@tmp, 'graphdb', 'migrate')
    FileUtils.mkdir_p(@graphdb)
    @connection = DummyAdapter.new(adapter: 'dummy')
  end

  def teardown
    FileUtils.rm_rf(@tmp)
    Object.send(:remove_const, :AddTestIndex) if defined?(AddTestIndex)
  end

  def write_migration(version, name, body)
    File.write(File.join(@graphdb, "#{version}_#{name}.rb"), body)
  end

  test 'migrator runs pending migrations' do
    write_migration('20250521113035', 'add_test_index', <<~RUBY)
      class AddTestIndex < ActiveCypher::Migration
        up do
          execute 'CREATE (n:Test {name: "A"})'
        end
      end
    RUBY

    Dir.chdir(@tmp) do
      ActiveCypher::Migrator.new(@connection).migrate!
    end

    assert_includes @connection.executed.first, 'CREATE CONSTRAINT graph_schema_migration'
    assert_includes @connection.executed[2], 'CREATE (n:Test'
    assert_match(/CREATE \(:SchemaMigration/, @connection.executed.last)
  end

  test 'migrator skips already applied versions' do
    write_migration('20250521113035', 'add_test_index', <<~RUBY)
      class AddTestIndex < ActiveCypher::Migration
        up { execute 'RETURN 1' }
      end
    RUBY

    Dir.chdir(@tmp) do
      ActiveCypher::Migrator.new(@connection).migrate!
      count_after_first = @connection.executed.size
      ActiveCypher::Migrator.new(@connection).migrate!
      assert_equal count_after_first + 2, @connection.executed.size
    end
  end
end
