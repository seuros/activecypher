# frozen_string_literal: true

require 'rails/generators/named_base'

module ActiveCypher
  module Generators
    class MigrationGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      def create_migration_file
        timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
        dir = File.join('graphdb', 'migrate')
        FileUtils.mkdir_p(dir)
        template 'migration.rb.erb', File.join(dir, "#{timestamp}_#{file_name}.rb")
      end
    end
  end
end
