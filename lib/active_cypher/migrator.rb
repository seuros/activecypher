# frozen_string_literal: true

module ActiveCypher
  # Runs pending graph database migrations.
  class Migrator
    MIGRATE_DIR = File.join('graphdb', 'migrate')

    def initialize(connection = ActiveCypher::Base.connection)
      @connection = connection
    end

    def migrate!
      ensure_schema_migration_constraint
      applied = existing_versions

      migration_files.each do |file|
        version = File.basename(file)[0, 14]
        next if applied.include?(version)

        require file
        class_name = File.basename(file, '.rb').split('_', 2).last.camelize
        klass = Object.const_get(class_name)
        klass.new(@connection).run

        @connection.execute_cypher(<<~CYPHER)
          CREATE (:SchemaMigration { version: '#{version}', executed_at: datetime() })
        CYPHER
      end
    end

    def status
      ensure_schema_migration_constraint
      applied = existing_versions
      migration_files.map do |file|
        version = File.basename(file)[0, 14]
        {
          status: (applied.include?(version) ? 'up' : 'down'),
          version: version,
          name: File.basename(file)
        }
      end
    end

    private

    def adapter_dir
      name = @connection.class.name.demodulize.sub('Adapter', '').downcase
      File.join('graphdb', name)
    end

    def migration_dirs
      dirs = [MIGRATE_DIR, adapter_dir]
      extra = @connection.config[:migrations_paths]
      dirs.concat(Array(extra)) if extra
      dirs
    end

    def migration_files
      migration_dirs.flat_map do |dir|
        Dir[File.expand_path(File.join(dir, '*.rb'), Dir.pwd)]
      end.sort
    end

    def existing_versions
      @connection.execute_cypher('MATCH (m:SchemaMigration) RETURN m.version AS version')
                 .map { |r| r[:version].to_s }
    end

    def ensure_schema_migration_constraint
      @connection.execute_cypher(<<~CYPHER)
        CREATE CONSTRAINT graph_schema_migration IF NOT EXISTS
        FOR (m:SchemaMigration)
        REQUIRE m.version IS UNIQUE
      CYPHER
    end
  end
end
