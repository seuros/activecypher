namespace :graphdb do
  desc 'Run graph database migrations'
  task migrate: :environment do
    ActiveCypher::Migrator.new.migrate!
    puts 'GraphDB migrations complete'
  end

  desc 'Show graph database migration status'
  task status: :environment do
    ActiveCypher::Migrator.new.status.each do |m|
      puts format('%-4s %s %s', m[:status], m[:version], m[:name])
    end
  end
end
