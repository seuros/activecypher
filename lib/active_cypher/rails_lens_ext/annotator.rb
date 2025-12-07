# frozen_string_literal: true

require_relative 'extension'

module ActiveCypher
  module RailsLensExt
    # Annotator for ActiveCypher graph models
    # Discovers and annotates Node and Relationship classes
    # Uses RailsLens-compatible TOML format and markers
    class Annotator
      # Use RailsLens-compatible marker format
      MARKER_FORMAT = 'rails-lens:graph'
      ANNOTATION_BEGIN = "# <#{MARKER_FORMAT}:begin>".freeze
      ANNOTATION_END = "# <#{MARKER_FORMAT}:end>".freeze

      class << self
        # Annotate all ActiveCypher models
        # @param options [Hash] Options for annotation
        # @option options [Boolean] :include_abstract Include abstract classes
        # @option options [Array<String>] :only Only annotate these models
        # @option options [Array<String>] :except Skip these models
        # @return [Hash] Results with :annotated, :skipped, :failed keys
        def annotate_all(options = {})
          results = { annotated: [], skipped: [], failed: [] }

          models = discover_models(options)

          models.each do |model|
            result = annotate_model(model, options)
            case result[:status]
            when :annotated
              results[:annotated] << result
            when :skipped
              results[:skipped] << result
            when :failed
              results[:failed] << result
            end
          end

          results
        end

        # Remove annotations from all ActiveCypher models
        # @param options [Hash] Options for removal
        # @return [Hash] Results with :removed, :skipped keys
        def remove_all(options = {})
          results = { removed: [], skipped: [] }

          models = discover_models(options.merge(include_abstract: true))

          models.each do |model|
            result = remove_annotation(model)
            if result[:status] == :removed
              results[:removed] << result
            else
              results[:skipped] << result
            end
          end

          results
        end

        # Annotate a single model
        # @param model [Class] The model class to annotate
        # @param options [Hash] Options
        # @return [Hash] Result with :status, :model, :file, :message keys
        def annotate_model(model, _options = {})
          file_path = model_file_path(model)

          return { status: :skipped, model: model.name, file: nil, message: 'File not found' } unless file_path && File.exist?(file_path)

          extension = Extension.new(model)
          annotation = extension.annotate

          return { status: :skipped, model: model.name, file: file_path, message: 'No annotation generated' } unless annotation

          begin
            write_annotation(file_path, model, annotation)
            { status: :annotated, model: model.name, file: file_path, message: 'Annotated successfully' }
          rescue StandardError => e
            { status: :failed, model: model.name, file: file_path, message: e.message }
          end
        end

        # Remove annotation from a single model
        # @param model [Class] The model class
        # @return [Hash] Result with :status, :model, :file keys
        def remove_annotation(model)
          file_path = model_file_path(model)

          return { status: :skipped, model: model.name, file: nil } unless file_path && File.exist?(file_path)

          content = File.read(file_path)

          if content.include?(ANNOTATION_BEGIN)
            new_content = ::RailsLens::FileInsertionHelper.remove_after_frozen_string_literal(
              content, '<rails-lens:graph:begin>', '<rails-lens:graph:end>'
            )
            new_content = new_content.gsub(/\n{3,}/, "\n\n")

            File.write(file_path, new_content)
            { status: :removed, model: model.name, file: file_path }
          else
            { status: :skipped, model: model.name, file: file_path }
          end
        end

        private

        # Discover all ActiveCypher models
        def discover_models(options = {})
          # Eager load all graph models
          eager_load_graph_models

          models = []

          # Find all Node classes (ActiveCypher::Base descendants)
          if defined?(::ActiveCypher::Base)
            ObjectSpace.each_object(Class) do |klass|
              next unless klass < ::ActiveCypher::Base
              next if klass == ::ActiveCypher::Base

              models << klass
            end
          end

          # Find all Relationship classes (ActiveCypher::Relationship descendants)
          if defined?(::ActiveCypher::Relationship)
            ObjectSpace.each_object(Class) do |klass|
              next unless klass < ::ActiveCypher::Relationship
              next if klass == ::ActiveCypher::Relationship

              models << klass
            end
          end

          # Filter out abstract classes unless requested
          models.reject! { |m| m.respond_to?(:abstract_class?) && m.abstract_class? } unless options[:include_abstract]

          # Filter by :only option
          if options[:only]
            only_names = Array(options[:only]).map(&:to_s)
            models.select! { |m| only_names.include?(m.name) }
          end

          # Filter by :except option
          if options[:except]
            except_names = Array(options[:except]).map(&:to_s)
            models.reject! { |m| except_names.include?(m.name) }
          end

          models.sort_by { |m| m.name || '' }
        end

        # Eager load graph models from Rails app
        def eager_load_graph_models
          return unless defined?(Rails) && Rails.respond_to?(:root)

          # Common paths for graph models
          graph_paths = [
            Rails.root.join('app', 'graph'),
            Rails.root.join('app', 'models', 'graph'),
            Rails.root.join('app', 'graphs')
          ]

          graph_paths.each do |path|
            next unless path.exist?

            Dir.glob(path.join('**', '*.rb')).each do |file|
              require file
            rescue LoadError, StandardError => e
              warn "[ActiveCypher] Failed to load #{file}: #{e.message}"
            end
          end
        end

        # Get the file path for a model
        def model_file_path(model)
          # Try const_source_location first (Ruby 2.7+)
          if model.respond_to?(:const_source_location)
            location = Object.const_source_location(model.name)
            return location&.first
          end

          # Fallback: try to find via instance method
          if model.instance_methods(false).any?
            method = model.instance_method(model.instance_methods(false).first)
            return method.source_location&.first
          end

          nil
        rescue StandardError
          nil
        end

        # Write annotation to file using RailsLens FileInsertionHelper
        def write_annotation(file_path, model, annotation)
          annotation_block = build_annotation_block(annotation)

          ::RailsLens::FileInsertionHelper.insert_at_class_definition(
            file_path,
            model.name.split('::').last,
            annotation_block
          )
        end

        # Build the annotation block with markers
        def build_annotation_block(annotation)
          lines = [ANNOTATION_BEGIN]
          annotation.each_line do |line|
            content = line.chomp
            lines << (content.empty? ? '#' : "# #{content}")
          end
          lines << ANNOTATION_END
          lines.join("\n")
        end
      end
    end
  end
end
