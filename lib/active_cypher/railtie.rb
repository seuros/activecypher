# frozen_string_literal: true

module ActiveCypher
  class Railtie < Rails::Railtie
    initializer 'active_cypher.extend_dummy_app' do |_app|
      puts 'Extending dummy app with ActiveCypher!'
    end
  end
end
