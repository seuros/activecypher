# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require_relative '../support/dummy_adapter'

class SchemaDumperTest < ActiveSupport::TestCase
  def setup
    @connection = DummyAdapter.new(adapter: 'dummy')
    @dumper = ActiveCypher::Schema::Dumper.new(@connection, base_dir: Dir.pwd)
  end

  test 'schema dump is idempotent' do
    first  = @dumper.dump_to_string
    second = @dumper.dump_to_string
    assert_equal first, second, 'Cypher dump must be idempotent'
  end

  test 'dump contains at least one create statement' do
    txt = @dumper.dump_to_string
    assert_match(/CREATE (CONSTRAINT|INDEX)/, txt)
  end
end
