class CreateMigrationTestRelIndex < ActiveCypher::Migration
  up do
    # Relationship index to cover adapter-specific edge index syntax
    create_rel_index :MIGRATES, :since, name: :migrates_since_idx
  end
end
