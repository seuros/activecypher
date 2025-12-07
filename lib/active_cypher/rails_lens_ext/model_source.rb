# frozen_string_literal: true

# Only define model source if RailsLens is available
# This file is loaded conditionally via railtie, not via autoload
return unless defined?(RailsLens::ModelSource)

require_relative 'annotator'

module ActiveCypher
  module RailsLensExt
    # Model source for ActiveCypher graph models
    # Provides integration with RailsLens annotation system
    class ModelSource < ::RailsLens::ModelSource
      class << self
        def models(options = {})
          Annotator.send(:discover_models, options)
        end

        def file_patterns
          ['app/graph/**/*.rb', 'app/models/graph/**/*.rb', 'app/graphs/**/*.rb']
        end

        def annotate_model(model, options = {})
          Annotator.annotate_model(model, options)
        end

        def remove_annotation(model)
          Annotator.remove_annotation(model)
        end

        def source_name
          'ActiveCypher Graph'
        end
      end
    end
  end

  # Register for auto-discovery by RailsLens (for gems with conventional names)
  RailsLensModelSource = RailsLensExt::ModelSource

  # Explicitly register with RailsLens (gem name 'activecypher' doesn't match 'ActiveCypher')
  ::RailsLens::ModelSourceLoader.register(RailsLensExt::ModelSource)
end
