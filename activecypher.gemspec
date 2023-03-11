# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'activecypher'
  spec.version = '0.0.0'
  spec.authors = ['Abdelkader Boudih']
  spec.email = ['seuros@pre-history.com']

  spec.summary = 'OpenCypher Adapter ala ActiveRecord'
  spec.description = spec.summary
  spec.homepage = 'https://github.com/seuros/activecypher'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.5'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/seuros/activecypher'

  spec.files = Dir.glob('{lib,sig}/**/*', File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activemodel', '~> 7.0'
end
