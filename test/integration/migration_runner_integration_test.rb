# frozen_string_literal: true

require 'test_helper'

class MigrationRunnerIntegrationTest < ActiveSupport::TestCase
  def setup
    @connections = {
      memgraph: ApplicationGraphNode.connection,
      neo4j: Neo4jRecord.connection
    }

    # Best-effort cleanup of artifacts that could block reruns
    drop_artifacts
  end

  test 'graph migrations run and report up for each configured connection' do
    @connections.each do |label, conn|
      migrator = ActiveCypher::Migrator.new(conn)
      migrator.migrate!

      statuses = migrator.status
      assert statuses.all? { |s| s[:status] == 'up' }, "Not all migrations are up for #{label}"
      assert statuses.any?, "No migrations found for #{label}"
    end
  end

  private

  def drop_artifacts
    # Drop any previously created objects so the test can run repeatably
    neo = @connections[:neo4j]
    mg  = @connections[:memgraph]

    if neo
      [
        "DROP CONSTRAINT migration_test_name_unique IF EXISTS",
        "DROP INDEX migration_test_name_idx IF EXISTS",
        "DROP INDEX migrates_since_idx IF EXISTS"
      ].each { |cy| neo.execute_cypher(cy) rescue nil }
    end

    if mg
      [
        "DROP CONSTRAINT ON (n:MigrationTest) ASSERT n.name IS UNIQUE",
        "DROP EDGE INDEX ON :MIGRATES(since)"
      ].each { |cy| mg.execute_cypher(cy) rescue nil }
      mg.execute_cypher('MATCH (m:SchemaMigration) DETACH DELETE m') rescue nil
    end
  end
end
