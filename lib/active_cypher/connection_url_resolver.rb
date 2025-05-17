# frozen_string_literal: true

require 'uri'
require 'cgi'

module ActiveCypher
  # ConnectionUrlResolver accepts Cypher-based database URLs and converts them
  # into a normalized configuration hash for adapter resolution.
  #
  # Supported URL prefixes:
  # - neo4j://
  # - neo4j+ssl://
  # - neo4j+ssc://
  # - memgraph://
  # - memgraph+ssl://
  # - memgraph+ssc://
  #
  # Database resolution:
  # - If specified in path: neo4j://localhost:7687/custom_db → db=custom_db
  # - Otherwise defaults based on adapter:
  #   - neo4j://localhost:7687 → db=neo4j
  #   - memgraph://localhost:7687 → db=memgraph
  #
  # The output of to_hash follows a consistent pattern:
  # {
  #   adapter: "neo4j", # or "memgraph"
  #   username: "user",
  #   password: "pass",
  #   host: "localhost",
  #   port: 7687,
  #   database: "neo4j", # or "memgraph" or custom path value
  #   ssl: true,
  #   ssc: false,
  #   options: {} # future-proof for params like '?timeout=30'
  # }
  class ConnectionUrlResolver
    SUPPORTED_ADAPTERS = %w[neo4j memgraph].freeze
    DEFAULT_PORT = 7687

    # Initialize with a URL string
    # @param url_string [String] A connection URL string
    def initialize(url_string)
      @url_string = url_string
      @parsed = parse_url(url_string)
    end

    # Convert the URL to a normalized hash configuration
    # @return [Hash] Configuration hash with adapter, host, port, etc.
    def to_hash
      return nil unless @parsed

      {
        adapter: @parsed[:adapter],
        host: @parsed[:host],
        port: @parsed[:port],
        username: @parsed[:username],
        password: @parsed[:password],
        database: @parsed[:database],
        ssl: @parsed[:ssl],
        ssc: @parsed[:ssc],
        options: @parsed[:options]
      }
    end

    private

    def parse_url(url_string)
      return nil if url_string.nil? || url_string.empty?

      # Extract scheme and potential modifiers (ssl, ssc)
      scheme_parts = url_string.split('://', 2)
      return nil if scheme_parts.size != 2

      scheme = scheme_parts[0]
      rest = scheme_parts[1].to_s

      adapter, modifiers = extract_adapter_and_modifiers(scheme)
      return nil unless adapter

      # Parse the remaining part as a standard URI
      uri_string = "#{adapter}://#{rest}"
      begin
        uri = URI.parse(uri_string)
      rescue URI::InvalidURIError
        return nil
      end

      # Extract query parameters, if any
      options = extract_query_params(uri.query)

      # Extract database from path, if present
      path_database = uri.path.empty? ? nil : uri.path.sub(%r{^/}, '')
      path_database = nil if path_database&.empty?

      # Determine database using factory pattern:
      # 1. Use path database if specified
      # 2. Otherwise fall back to adapter name as default
      database = path_database || adapter

      # The to_s conversion handles nil values
      username = uri.user.to_s.empty? ? nil : CGI.unescape(uri.user)
      password = uri.password.to_s.empty? ? nil : CGI.unescape(uri.password)

      # When using SSC (self-signed certificates), SSL must also be enabled
      use_ssl = modifiers.include?('ssl')
      use_ssc = modifiers.include?('ssc')

      # Self-signed certificates imply SSL is also enabled
      use_ssl = true if use_ssc

      {
        adapter: adapter,
        host: uri.host || 'localhost',
        port: uri.port || DEFAULT_PORT,
        username: username,
        password: password,
        database: database,
        ssl: use_ssl,
        ssc: use_ssc,
        options: options
      }
    end

    def extract_adapter_and_modifiers(scheme)
      parts = scheme.split('+')
      adapter = parts.shift

      return nil unless SUPPORTED_ADAPTERS.include?(adapter)

      modifiers = parts.select { |mod| %w[ssl ssc].include?(mod) }

      # If there are parts that are neither the adapter nor valid modifiers, the URL is invalid
      remaining_parts = parts - modifiers
      return nil if remaining_parts.any?

      [adapter, modifiers]
    end

    def extract_query_params(query_string)
      return {} unless query_string

      query_string.split('&').each_with_object({}) do |pair, hash|
        key, value = pair.split('=', 2)
        hash[key.to_sym] = value if key && !key.empty? && value && !value.empty?
      end
    end
  end
end
