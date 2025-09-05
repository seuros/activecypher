# frozen_string_literal: true

require 'active_support/notifications'

module ActiveCypher
  # Instrumentation for ActiveCypher operations.
  # Because every database operation needs a stopwatch and an audience.
  module Instrumentation
    # ------------------------------------------------------------------
    # Core instrumentation method
    # ------------------------------------------------------------------

    # Instruments an operation and publishes an event with timing information.
    # @param operation [String, Symbol] The operation name (prefixed with 'active_cypher.')
    # @param payload [Hash] Additional context for the event
    # @yield The operation to instrument
    # @return [Object] The result of the block
    def instrument(operation, payload = {})
      # Start timing with monotonic clock for accuracy (because wall time is for amateurs)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Run the actual operation
      result = yield

      # Calculate duration in milliseconds (because counting seconds is so 1990s)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1_000).round(2)

      # Add duration to payload
      payload[:duration_ms] = duration_ms

      # Publish event via ActiveSupport::Notifications
      event_name = operation.to_s.start_with?('active_cypher.') ? operation.to_s : "active_cypher.#{operation}"
      ActiveSupport::Notifications.instrument(event_name, payload)

      # Also log if we have logging capabilities
      log_instrumented_event(operation, payload) if respond_to?(:logger)

      # Return the original result
      result
    end

    # ------------------------------------------------------------------
    # Specialized instrumentation methods
    # ------------------------------------------------------------------

    # Instruments a database query.
    # @param cypher [String] The Cypher query
    # @param params [Hash] Query parameters
    # @param context [String] Additional context (e.g., "Model.find")
    # @param metadata [Hash] Additional metadata
    # @yield The query operation
    # @return [Object] The result of the block
    def instrument_query(cypher, params = {}, context: 'Query', metadata: {}, &)
      truncated_cypher = cypher.to_s.gsub(/\s+/, ' ').strip
      truncated_cypher = "#{truncated_cypher[0...97]}..." if truncated_cypher.length > 100

      payload = metadata.merge(
        cypher: truncated_cypher,
        params: sanitize_params(params),
        context: context
      )

      instrument('query', payload, &)
    end

    # Instruments a connection operation.
    # @param operation [Symbol] The connection operation (:connect, :disconnect, etc)
    # @param config [Hash] Connection configuration
    # @param metadata [Hash] Additional metadata
    # @yield The connection operation
    # @return [Object] The result of the block
    def instrument_connection(operation, config = {}, metadata: {}, &)
      payload = metadata.merge(
        config: sanitize_config(config)
      )

      instrument("connection.#{operation}", payload, &)
    end

    # Instruments a transaction operation.
    # @param operation [Symbol] The transaction operation (:begin, :commit, :rollback)
    # @param transaction_id [String, Integer] Transaction identifier (if available)
    # @param metadata [Hash] Additional metadata
    # @yield The transaction operation
    # @return [Object] The result of the block
    def instrument_transaction(operation, transaction_id = nil, metadata: {}, &)
      payload = metadata.dup
      payload[:transaction_id] = transaction_id if transaction_id

      instrument("transaction.#{operation}", payload, &)
    end

    # ------------------------------------------------------------------
    # Sanitization methods
    # ------------------------------------------------------------------

    # Sanitizes query parameters to remove sensitive values.
    # @param params [Hash, Object] The parameters to sanitize
    # @return [Hash, Object] Sanitized parameters
    def sanitize_params(params)
      return params unless params.is_a?(Hash)

      params.each_with_object({}) do |(key, value), sanitized|
        sanitized[key] = if sensitive_key?(key)
                           '[FILTERED]'
                         elsif value.is_a?(Hash)
                           sanitize_params(value)
                         else
                           value
                         end
      end
    end

    # Sanitizes connection configuration to remove sensitive values.
    # @param config [Hash] The configuration to sanitize
    # @return [Hash] Sanitized configuration
    def sanitize_config(config)
      return {} unless config.is_a?(Hash)

      config.each_with_object({}) do |(key, value), result|
        result[key] = if sensitive_key?(key)
                        '[FILTERED]'
                      elsif value.is_a?(Hash)
                        sanitize_config(value)
                      else
                        value
                      end
      end
    end

    # Determines if a key contains sensitive information that should be filtered.
    # @param key [String, Symbol] The key to check
    # @return [Boolean] True if the key contains sensitive information
    def sensitive_key?(key)
      return true if key.to_s.match?(/(^|[-_])(?:password|token|secret|credential|key)($|[-_])/i)

      # Check against Rails filter parameters if available
      if defined?(Rails) && Rails.application
        Rails.application.config.filter_parameters.any? do |pattern|
          case pattern
          when Regexp
            key.to_s =~ pattern
          when Symbol, String
            key.to_s == pattern.to_s
          else
            false
          end
        end
      else
        false
      end
    end

    private

    # ------------------------------------------------------------------
    # Logging integration
    # ------------------------------------------------------------------
    # Logs an instrumented event if logging is available.
    # @param operation [String, Symbol] The operation name
    # @param payload [Hash] The event payload
    def log_instrumented_event(operation, payload)
      return unless respond_to?(:log_debug)

      # Format duration if available
      duration_text = payload[:duration_ms] ? " (#{payload[:duration_ms]} ms)" : ''
      operation_name = operation.to_s.sub(/^active_cypher\./, '')

      case operation_name
      when /query/
        log_debug("QUERY#{duration_text}: #{payload[:cypher]}")
        log_debug("PARAMS: #{payload[:params].inspect}") if payload[:params]
      when /connection/
        op = operation_name.sub(/^connection\./, '')
        log_debug("CONNECTION #{op.upcase}#{duration_text}")
      when /transaction/
        op = operation_name.sub(/^transaction\./, '')
        tx_id = payload[:transaction_id] ? " (ID: #{payload[:transaction_id]})" : ''
        log_debug("TRANSACTION #{op.upcase}#{tx_id}#{duration_text}")
      else
        # Generic fallback, for when you just don't know how to categorize your problems
        log_debug("#{operation_name.upcase}#{duration_text}")
      end
    end
  end
end
