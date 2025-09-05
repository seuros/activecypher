# frozen_string_literal: true

module ActiveCypher
  module Fixtures
    # Something went wrong with your test fixtures.
    # Maybe they're on vacation. Maybe they're just imaginary.
    class FixtureError < StandardError; end

    # You asked for a fixture that doesn't exist.
    # It's playing hide and seek. Mostly hide.
    class FixtureNotFoundError < StandardError; end

    # Load a graph fixture profile.
    # @param profile [Symbol, String, nil] the profile name (default: :default)
    # @return [void]
    def self.load(profile: nil)
      # 1. Resolve file
      profile_name = (profile || :default).to_s
      fixtures_dir = File.expand_path('test/fixtures/graph', Dir.pwd)
      file = File.join(fixtures_dir, "#{profile_name}.rb")
      raise FixtureNotFoundError, "Fixture profile not found: #{profile_name} (#{file})" unless File.exist?(file)

      # 2. Reset registry
      Registry.reset!

      # 3. Parse the profile file (to discover which models are referenced)
      parser = Parser.new(file)
      dsl_context = parser.parse

      # 4. Validate relationships upfront (cross-DB)
      validate_relationships(dsl_context.relationships)

      # 5. Gather unique connections for all model classes referenced in this profile
      model_classes = dsl_context.nodes.map { |node| node[:model_class] }.uniq
      connections = model_classes.map(&:connection).compact.uniq

      # 6. Wipe all nodes in each relevant connection
      connections.each do |conn|
        conn.execute_cypher('MATCH (n) DETACH DELETE n')
      rescue StandardError => e
        warn "[ActiveCypher::Fixtures.load] Failed to clear connection #{conn.inspect}: #{e.class}: #{e.message}"
      end

      # 7. Evaluate nodes and relationships (batched if large)
      if dsl_context.nodes.size > 100 || dsl_context.relationships.size > 200
        NodeBuilder.bulk_build(dsl_context.nodes)
        # Create all nodes first, then validate relationships again with populated Registry
        validate_relationships(dsl_context.relationships)
        RelBuilder.bulk_build(dsl_context.relationships)
      else
        dsl_context.nodes.each do |node|
          NodeBuilder.build(node[:ref], node[:model_class], node[:props])
        end
        rel_builder = RelBuilder.new
        dsl_context.relationships.each do |rel|
          rel_builder.build(rel[:ref], rel[:from_ref], rel[:type], rel[:to_ref], rel[:props])
        end
      end

      # 8. Return registry for convenience
      Registry
    end

    # Clear all nodes in all known connections.
    # @return [void]
    def self.clear_all
      # Find all concrete (non-abstract) model classes inheriting from ActiveCypher::Base
      model_classes = []
      ObjectSpace.each_object(Class) do |klass|
        next unless klass < ActiveCypher::Base
        next if klass.respond_to?(:abstract_class?) && klass.abstract_class?

        model_classes << klass
      end

      # Gather unique connections from all model classes
      connections = model_classes.map(&:connection).compact.uniq

      # Wipe all nodes in each connection
      connections.each do |conn|
        conn.execute_cypher('MATCH (n) DETACH DELETE n')
      rescue StandardError => e
        warn "[ActiveCypher::Fixtures.clear_all] Failed to clear connection #{conn.inspect}: #{e.class}: #{e.message}"
      end
      true
    end

    # Validates relationships for cross-DB issues
    # @param relationships [Array<Hash>] array of relationship definitions
    # @raise [FixtureError] if cross-DB relationship is found
    def self.validate_relationships(relationships)
      model_connections = {}

      # First build a mapping of model class => connection details
      ObjectSpace.each_object(Class) do |klass|
        next unless klass < ActiveCypher::Base
        next if klass.respond_to?(:abstract_class?) && klass.abstract_class?

        conn = klass.connection
        # Store connection details for comparison
        model_connections[klass] = {
          adapter: conn.class.name,
          config: conn.instance_variable_get(:@config),
          object_id: conn.object_id
        }
      end

      relationships.each do |rel|
        from_ref = rel[:from_ref]
        to_ref = rel[:to_ref]

        # Get node classes from DSL context
        # In real data, nodes have already been created by this point
        from_node = Registry.get(from_ref)
        to_node = Registry.get(to_ref)

        # Skip if we can't find both nodes yet (will be caught later)
        next unless from_node && to_node

        from_class = from_node.class
        to_class = to_node.class

        # Look up connection details for each class
        from_conn_details = model_connections[from_class]
        to_conn_details = model_connections[to_class]

        # If either class isn't in our mapping, refresh it
        unless from_conn_details
          conn = from_class.connection
          from_conn_details = {
            adapter: conn.class.name,
            config: conn.instance_variable_get(:@config),
            object_id: conn.object_id
          }
          model_connections[from_class] = from_conn_details
        end

        unless to_conn_details
          conn = to_class.connection
          to_conn_details = {
            adapter: conn.class.name,
            config: conn.instance_variable_get(:@config),
            object_id: conn.object_id
          }
          model_connections[to_class] = to_conn_details
        end

        # Compare connection details
        next unless from_conn_details[:object_id] != to_conn_details[:object_id] ||
                    from_conn_details[:adapter] != to_conn_details[:adapter] ||
                    from_conn_details[:config][:database] != to_conn_details[:config][:database]

        raise FixtureError, 'Cross-database relationship? Sorry, your data has commitment issues. ' \
                            "Nodes #{from_ref} (#{from_class}) and #{to_ref} (#{to_class}) use different databases."
      end
    end

    # Fetch a node by logical ref.
    # @param ref [Symbol, String]
    # @return [Object]
    def self.[](ref)
      Registry[ref]
    end
  end
end
