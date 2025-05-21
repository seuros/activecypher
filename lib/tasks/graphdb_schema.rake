# frozen_string_literal: true

namespace :graphdb do
  namespace :schema do
    desc 'Dump current graph schema to graphdb/schema*.cypher'
    task dump: :environment do
      ActiveCypher::Schema::Dumper.run_from_cli
    end
  end
end
