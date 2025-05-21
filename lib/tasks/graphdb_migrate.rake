# frozen_string_literal: true

namespace :graphdb do
  # bin/rails graphdb:migrate
  desc 'Run graph database migrations'
  task migrate: :environment do
    ActiveCypher::Migrator.new.migrate!
    puts 'GraphDB migrations complete'
  end

  # bin/rails graphdb:status
  desc 'Show graph database migration status'
  task status: :environment do
    ActiveCypher::Migrator.new.status.each do |m|
      puts format('%-4<status>s %<version>s %<name>s', m)
    end
  end
end
