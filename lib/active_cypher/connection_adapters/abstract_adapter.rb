# frozen_string_literal: true

require 'logger'
require 'date'
require 'active_support/core_ext/hash/indifferent_access'

module ActiveCypher
  module ConnectionAdapters
    # Minimal contract every graph adapter must fulfil.
    # @note Because every project needs an abstract class to remind you that nothing is ever truly implemented.
    class AbstractAdapter
      attr_reader :config

      # Initializes the adapter, because you can't spell "configuration" without "con."
      # @param config [Hash] The configuration hash for the adapter
      def initialize(config) = (@config = config)

      # ---- lifecycle ---------------------------------------------------------
      # The lifecycle methods. Spoiler: most of them do nothing.
      def connect                 = raise(AdapterNotFoundError)
      def disconnect              = true
      def active?                 = false
      def reconnect               = disconnect && connect

      # ---- Cypher ------------------------------------------------------------
      # Executes a Cypher query, or at least raises an error about it.
      # @raise [NotImplementedError] Always, unless implemented by subclass.
      def execute_cypher(*)
        raise NotImplementedError, "#{self.class} must implement #execute_cypher"
      end

      # ---- transactions (optional) ------------------------------------------
      # Transaction methods: for when you want to pretend you have ACID.
      def begin_transaction       = nil
      def commit_transaction(_)   = true
      def rollback_transaction(_) = true

      # ---- helpers -----------------------------------------------------------
      # Prepares parameters for Cypher, because the database can't read your mind. Yet.
      # @param raw [Object] The raw parameter value
      # @return [Object] The prepared parameter
      def prepare_params(raw)
        case raw
        when Hash  then raw.transform_keys(&:to_s).transform_values { |v| prepare_params(v) }
        when Array then raw.each_with_index.to_h { |v, i| ["p#{i + 1}", prepare_params(v)] }
        when Time, Date, DateTime then raw.iso8601
        when Symbol then raw.to_s
        else raw # String/Integer/Float/Boolean/NilClass
        end
      end

      # Hydrates attributes from a database record
      # @param record [Hash] The raw record from the database
      # @param node_alias [Symbol] The alias used for the node in the query
      # @return [Hash] The hydrated attributes
      def hydrate_record(record, node_alias)
        raise NotImplementedError, "#{self.class} must implement #hydrate_record"
      end


      # Turns rows into symbols, because Rubyists fear strings.
      # @param rows [Array<Hash>] The rows to process
      # @return [Array<Hash>] The processed rows
      def process_records(rows) = rows.map { |r| deep_symbolize(r) }

      # Override inspect to hide sensitive information
      # @return [String] Safe representation of the adapter
      def inspect
        filtered_config = ActiveCypher::Redaction.filter_hash(config)

        # Return a safe representation
        "#<#{self.class}:0x#{object_id.to_s(16)} @config=#{filtered_config.inspect}>"
      end

      private

      # Recursively turns everything into symbols, because that's what all the cool kids do.
      # @param obj [Object] The object to symbolize
      # @return [Object] The symbolized object
      def deep_symbolize(obj)
        case obj
        when Hash  then obj.transform_keys(&:to_sym).transform_values { |v| deep_symbolize(v) }
        when Array then obj.map { |v| deep_symbolize(v) }
        else obj
        end
      end

      # Returns the logger, or creates a new one if Rails isn't watching.
      # @return [Logger] The logger instance
      def logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
    end
  end
end
