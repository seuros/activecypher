# frozen_string_literal: true

require 'logger'
require 'active_support/tagged_logging'

module Cyrel
  # Basic logging support for Cyrel.
  # Debug logging is disabled by default.
  module Logging
    LOG_TAG = 'Cyrel'

    class << self
      # @return [Logger] the configured logger
      attr_accessor :backend

      def resolve_log_level(log_level_str)
        Logger.const_get(log_level_str.upcase)
      end

      def logger
        self.backend ||= begin
          log_level = ENV.fetch('CYREL_LOG_LEVEL', 'unknown')
          logger_base = Logger.new($stdout)
          logger_base.level = resolve_log_level(log_level)

          # Return a TaggedLogging instance without calling 'tagged!'
          ActiveSupport::TaggedLogging.new(logger_base)
        end
      end
    end

    def logger
      Logging.logger.tagged(LOG_TAG)
    end

    def log_debug(msg) = logger.debug { msg }
    def log_info(msg)  = logger.info  { msg }
    def log_warn(msg)  = logger.warn  { msg }
    def log_error(msg) = logger.error { msg }
  end
end
