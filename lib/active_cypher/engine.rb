# frozen_string_literal: true

module ActiveCypher
  class Engine < ::Rails::Engine
    isolate_namespace ActiveCypher

    # Add the engine's lib directory to the application's autoload paths
    # This ensures Zeitwerk can find engine constants like ActiveCypher::Base, etc.
    config.autoload_paths << File.expand_path('..', __dir__)
  end
end
