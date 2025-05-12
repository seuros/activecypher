# frozen_string_literal: true

require 'test_helper'
require 'active_cypher/cypher_config'

class CypherConfigMissingFileTest < Minitest::Test
  DUMMY_PATH = File.expand_path('nonexistent_cypher_databases.yml', __dir__)

  def setup
    @original_default_path = ActiveCypher::CypherConfig.method(:default_path)
    # Stub default_path to a guaranteed-nonexistent file
    ActiveCypher::CypherConfig.singleton_class.define_method(:default_path) { DUMMY_PATH }
    @original_env = ENV.fetch('ACTIVE_CYPHER_SILENT_MISSING', nil)
  end

  def teardown
    # Restore original default_path
    ActiveCypher::CypherConfig.singleton_class.define_method(:default_path, @original_default_path)
    ENV['ACTIVE_CYPHER_SILENT_MISSING'] = @original_env
  end

  def test_for_star_returns_empty_hash_when_file_missing
    result = ActiveCypher::CypherConfig.for('*')
    assert_kind_of Hash, result
    assert result.empty?, 'Expected empty hash when config file is missing'
  end

  def test_for_specific_connection_raises_error_by_default
    error = assert_raises(RuntimeError) do
      ActiveCypher::CypherConfig.for(:primary)
    end
    assert_match(/Could not load ActiveCypher configuration/, error.message)
    assert_match(/generate active_cypher:install/, error.message)
  end

  def test_for_specific_connection_returns_nil_when_silent_missing_env_set
    ENV['ACTIVE_CYPHER_SILENT_MISSING'] = 'true'
    result = ActiveCypher::CypherConfig.for(:primary)
    assert_nil result
  end
end
