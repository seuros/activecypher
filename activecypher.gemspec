# frozen_string_literal: true

require_relative 'lib/active_cypher/version'

Gem::Specification.new do |spec|
  spec.name = 'activecypher'
  spec.version = ActiveCypher::VERSION
  spec.authors = ['Abdelkader Boudih']
  spec.email = ['seuros@pre-history.com']

  spec.summary = 'OpenCypher Adapter ala ActiveRecord'
  spec.description = spec.summary
  spec.homepage = 'https://github.com/seuros/activecypher'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/seuros/activecypher'

  spec.files = Dir.glob('{lib,sig}/**/*', File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activemodel', '~> 8.0'
  spec.add_dependency 'async', '~> 2.34'
  spec.add_dependency 'async-pool', '>= 0.11.0'
  spec.add_dependency 'io-endpoint', '~> 0.14'
  spec.add_dependency 'io-event', '~> 1.10'
  spec.add_dependency 'io-stream', '~> 0.6'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
