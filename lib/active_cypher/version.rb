# frozen_string_literal: true

module ActiveCypher
  VERSION = '0.8.1'

  def self.gem_version
    Gem::Version.new VERSION
  end

  class << self
    alias version gem_version
  end
end
