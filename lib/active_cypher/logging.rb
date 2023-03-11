# frozen_string_literal: true

require 'active_support/tagged_logging'
require 'active_support/logger'

module ActiveCypher
  module Logging
    extend ActiveSupport::Concern

    included do
      cattr_accesor :logger, default: ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
    end
  end
end
