class CreateMigrationTestNodes < ActiveCypher::Migration
  up do
    # Basic DDL to exercise both Memgraph and Neo4j adapters
    create_uniqueness_constraint :MigrationTest, :name
  end
end
