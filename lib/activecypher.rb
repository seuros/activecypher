# frozen_string_literal: true

require 'active_support'
require 'zeitwerk'
require_relative 'cyrel'

module ActiveCypher
  class Error < StandardError; end
end

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/active_cypher/railtie.rb")
loader.ignore("#{__dir__}/active_cypher/version.rb")
loader.ignore("#{__dir__}/activecypher.rb")
loader.ignore("#{__dir__}/cyrel.rb")
loader.inflector.inflect('activecypher' => 'ActiveCypher')
loader.push_dir("#{__dir__}/cyrel", namespace: Cyrel)
loader.setup
