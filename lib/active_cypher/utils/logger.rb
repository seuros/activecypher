# frozen_string_literal: true

require 'logger'
require 'singleton'

module ActiveCypher
  module Utils
    # A singleton logger class for ActiveCypher
    class Logger
      include Singleton

      attr_accessor :logger

      def initialize
        @logger = ::Logger.new($stdout)
        @logger.level = ::Logger::INFO
        @logger.formatter = self.class.standard_formatter
      end

      # Configure the logger
      # @param options [Hash] Configuration options
      # @option options [IO] :output Where to send logs (default: $stdout)
      # @option options [Symbol, Integer] :level Log level (default: :info)
      # @option options [Proc] :formatter Custom formatter for log messages
      def configure(options = {})
        @logger = ::Logger.new(options[:output]) if options[:output]

        if options[:level]
          level = options[:level]
          level = ::Logger.const_get(level.to_s.upcase) if level.is_a?(Symbol)
          @logger.level = level
        end

        @logger.formatter = options[:formatter] if options[:formatter]

        self
      end

      # Logger delegation methods
      %i[debug info warn error fatal].each do |level|
        define_method(level) do |message|
          @logger.send(level, message)
        end

        # Define class methods that delegate to the instance
        define_singleton_method(level) do |message|
          instance.send(level, message)
        end
      end

      # Get the current logger level
      # @return [Integer] Current log level
      def level
        @logger.level
      end

      # Set the logger level
      # @param level [Symbol, Integer] The log level
      def level=(level)
        level = ::Logger.const_get(level.to_s.upcase) if level.is_a?(Symbol)
        @logger.level = level
      end

      # Class methods that delegate to the instance
      class << self
        def configure(options = {})
          instance.configure(options)
        end

        def level
          instance.level
        end

        def level=(level)
          instance.level = level
        end

        # Returns a standard formatter with time stamp
        # @return [Proc] A standard log formatter
        def standard_formatter
          proc do |severity, time, _progname, msg|
            time_str = time.strftime('%H:%M:%S.%L')
            "[#{time_str}] #{severity}: #{msg}\n"
          end
        end

        # Setup with standard configuration for all examples
        # @return [self]
        def setup
          configure(formatter: standard_formatter)
        end
      end
    end
  end
end

# Convenience method for accessing the logger
def logger
  ActiveCypher::Utils::Logger.instance.logger
end
