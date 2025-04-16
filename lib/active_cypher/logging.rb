# frozen_string_literal: true

require 'logger'
require 'active_support/tagged_logging'

module ActiveCypher
  module Logging
    class << self
      # The one true logger object
      attr_accessor :backend

      # Public accessor used by the mix‑in
      def logger
        self.backend ||= begin
          base = Logger.new($stdout)
          base.level = ENV.fetch('AC_LOG_LEVEL', 'info').upcase
                          .then do |lvl|
            Logger.const_get(lvl)
          rescue StandardError
            Logger::INFO
          end
          ActiveSupport::TaggedLogging.new(base).tap { |l| l.tagged! 'ActiveCypher' }
        end
      end
    end

    # ------------------------------------------------------------------
    #  Instance helpers
    # ------------------------------------------------------------------
    def logger         = Logging.logger
    def log_debug(msg) = logger.debug { msg }
    def log_info(msg)  = logger.info  { msg }
    def log_warn(msg)  = logger.warn  { msg }
    def log_error(msg) = logger.error { msg }

    def log_bench(label)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
    ensure
      ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1_000).round(2)
      logger.debug { "#{label} (#{ms} ms)" }
    end
  end
end
