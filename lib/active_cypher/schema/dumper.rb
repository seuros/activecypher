require 'fileutils'
require 'optparse'

module ActiveCypher
  module Schema
    # Dumps the graph schema to a Cypher script
    class Dumper
      DEFAULT_PATH = 'graphdb'.freeze

      def initialize(connection = ActiveCypher::Base.connection, base_dir: Dir.pwd)
        @connection = connection
        @base_dir   = base_dir
      end

      def dump_to_string
        cat = @connection.schema_catalog
        cat = catalog_from_migrations if cat.respond_to?(:empty?) && cat.empty?
        Writer::Cypher.new(cat, @connection.vendor).to_s
      end

      def dump_to_file(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, dump_to_string)
        path
      end

      def self.run_from_cli(argv = ARGV)
        opts = { stdout: false, connection: :primary }
        OptionParser.new do |o|
          o.on('--stdout') { opts[:stdout] = true }
          o.on('--connection=NAME') { |v| opts[:connection] = v.to_sym }
        end.parse!(argv)

        pool = ActiveCypher::Base.connection_handler.pool(opts[:connection])
        raise "Unknown connection: #{opts[:connection]}" unless pool

        dumper = new(pool.connection)
        file = output_file(opts[:connection])
        if opts[:stdout]
          puts dumper.dump_to_string
        else
          dumper.dump_to_file(file)
          puts "Written #{file}"
        end
      end

      def self.output_file(conn)
        case conn.to_sym
        when :primary
          File.join(DEFAULT_PATH, 'schema.cypher')
        when :analytics
          File.join(DEFAULT_PATH, 'schema.analytics.cypher')
        else
          File.join(DEFAULT_PATH, "schema.#{conn}.cypher")
        end
      end

      private

      def catalog_from_migrations
        idx = []
        cons = []
        Dir[File.join(@base_dir, 'graphdb', 'migrate', '*.rb')].sort.each do |file|
          require file
          class_name = File.basename(file, '.rb').split('_', 2).last.camelize
          klass = Object.const_get(class_name)
          mig = klass.new(@connection)
          mig.instance_eval(&klass.up_block) if klass.respond_to?(:up_block) && klass.up_block
          mig.operations.each do |cy|
            if cy =~ /CREATE\s+(UNIQUE\s+)?INDEX/i
              unique = !Regexp.last_match(1).nil?
              name = cy[/CREATE\s+(?:UNIQUE\s+)?INDEX\s+(\w+)/i, 1] || 'idx'
              label = cy[/\(n:`?([^:`)]+)`?\)/, 1] || 'Unknown'
              props = cy[/ON \(([^)]+)\)/i, 1].to_s.split(',').map { |p| p.strip.sub(/^n\./, '').sub(/^r\./, '') }
              elem = cy.include?('-[r:') ? :relationship : :node
              idx << IndexDef.new(name, elem, label, props, unique, nil)
            elsif cy =~ /CREATE\s+CONSTRAINT/i
              name = cy[/CREATE\s+CONSTRAINT\s+(\w+)/i, 1] || 'constraint'
              label = cy[/\(n:`?([^:`)]+)`?\)/, 1] || 'Unknown'
              if cy =~ /UNIQUE/i
                props = cy[/\(([^)]+)\)/, 1].to_s.split(',').map { |p| p.strip.sub(/^n\./, '') }
                kind = :unique
              else
                prop = cy[/n\.(\w+)\s+IS NOT NULL/i, 1]
                props = [prop].compact
                kind = :exists
              end
              cons << ConstraintDef.new(name, label, props, kind)
            end
          end
        end
        Catalog.new(indexes: idx, constraints: cons, node_types: [], edge_types: [])
      end
    end
  end
end
