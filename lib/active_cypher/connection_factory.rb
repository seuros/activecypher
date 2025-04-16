# frozen_string_literal: true

module ActiveCypher
  # ConnectionFactory provides a simple API for creating connections to Cypher databases
  # using the ConnectionUrlResolver to parse database URLs.
  #
  # This factory simplifies the process of creating database connections by:
  # 1. Parsing connection URLs with ConnectionUrlResolver
  # 2. Creating the appropriate adapter based on the URL
  # 3. Establishing and configuring the connection with the right security settings
  #
  # Example:
  #   factory = ConnectionFactory.new("neo4j://user:pass@localhost:7687")
  #   driver = factory.create_driver
  #
  #   driver.with_session do |session|
  #     result = session.run("RETURN 'Connected!' AS message")
  #     puts result.first[:message]
  #   end
  class ConnectionFactory
    # Initialize with a database URL
    # @param url [String] A database connection URL
    # @param options [Hash] Additional options for the connection
    def initialize(url, options = {})
      @url = url
      @options = options
      @config = resolve_url(url)
    end

    # Create a Bolt driver based on the parsed URL
    # @param pool_size [Integer] Size of the connection pool
    # @return [ActiveCypher::Bolt::Driver, nil] The configured driver or nil if URL is invalid
    def create_driver(pool_size: 5)
      return nil unless @config

      # Create the adapter based on the resolved configuration
      adapter = create_adapter
      return nil unless adapter

      # Create and configure the Bolt driver
      uri = build_uri
      auth_token = build_auth_token

      ActiveCypher::Bolt::Driver.new(
        uri: uri,
        adapter: adapter,
        auth_token: auth_token,
        pool_size: pool_size
      )
    end

    # Get the parsed configuration
    # @return [Hash, nil] The parsed configuration or nil if URL is invalid
    attr_reader :config

    # Verify if the URL is valid and supported
    # @return [Boolean] True if the URL is valid and supported
    def valid?
      !@config.nil?
    end

    private

    # Resolve the URL into a configuration hash
    def resolve_url(url)
      resolver = ConnectionUrlResolver.new(url)
      resolver.to_hash
    end

    # Create the appropriate adapter based on the parsed URL
    def create_adapter
      case @config[:adapter]
      when 'neo4j'
        create_neo4j_adapter
      when 'memgraph'
        create_memgraph_adapter
      else
        nil
      end
    end

    # Create a Neo4j adapter
    def create_neo4j_adapter
      ConnectionAdapters::Neo4jAdapter.new({
                                             uri: build_uri,
                                             username: @config[:username],
                                             password: @config[:password],
                                             database: @config[:database]
                                           })
    end

    # Create a Memgraph adapter
    def create_memgraph_adapter
      ConnectionAdapters::MemgraphAdapter.new({
                                                uri: build_uri,
                                                username: @config[:username],
                                                password: @config[:password],
                                                database: @config[:database]
                                              })
    rescue NameError
      # Fall back to Neo4j adapter if Memgraph adapter is not available
      ConnectionAdapters::Neo4jAdapter.new({
                                             uri: build_uri,
                                             username: @config[:username],
                                             password: @config[:password],
                                             database: @config[:database]
                                           })
    end

    # Build the URI string with the appropriate scheme based on SSL settings
    def build_uri
      scheme = if @config[:ssl]
                 @config[:ssc] ? 'bolt+ssc' : 'bolt+s'
               else
                 'bolt'
               end

      "#{scheme}://#{@config[:host]}:#{@config[:port]}"
    end

    # Build the authentication token for the Bolt driver
    def build_auth_token
      {
        scheme: 'basic',
        principal: @config[:username],
        credentials: @config[:password]
      }
    end
  end
end
