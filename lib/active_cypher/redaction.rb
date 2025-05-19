# frozen_string_literal: true

module ActiveCypher
  # Shared constants and utilities for redacting sensitive information in inspection output
  module Redaction
    # The mask to use for sensitive information
    MASK = '[HUNTER2]'

    # Common sensitive parameter keys
    SENSITIVE_KEYS = %i[password credentials auth_token principal url].freeze

    # Create a parameter filter with the default mask and keys
    # @param additional_keys [Array<Symbol>] Additional keys to redact
    # @return [ActiveSupport::ParameterFilter] The configured filter
    def self.create_filter(additional_keys = [])
      keys = SENSITIVE_KEYS + additional_keys
      ActiveSupport::ParameterFilter.new(keys, mask: MASK)
    end

    # Filter a hash to redact sensitive information
    # @param hash [Hash] The hash to filter
    # @param additional_keys [Array<Symbol>] Additional keys to redact
    # @return [Hash] The filtered hash
    def self.filter_hash(hash, additional_keys = [])
      create_filter(additional_keys).filter(hash)
    end
  end
end
