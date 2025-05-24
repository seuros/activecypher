# frozen_string_literal: true

module ActiveCypher
  # Module to handle association definitions (has_many, belongs_to, etc.)
  # for ActiveCypher models.
  # @note Because every DSL wants to be ActiveRecord when it grows up.
  module Associations
    extend ActiveSupport::Concern

    included do
      # Storage for association reflection metadata on the class
      # Because nothing says "enterprise" like a hash of hashes.
      class_attribute :_reflections, instance_writer: false, default: {}
    end

    class_methods do
      # Defines a one-to-many association.
      #
      # @param name [Symbol] The name of the association (e.g., :posts).
      # @param options [Hash] Configuration options:
      #   - :class_name [String] The class name of the associated model (e.g., "Post").
      #     Defaults to the camelized singular name.
      #   - :relationship [String] The type of the graph relationship (e.g., "WROTE").
      #     Defaults to the upcased association name.
      #   - :direction [:in, :out, :both] The direction of the relationship relative to this model.
      #     Defaults to :out for has_many.
      #   - (Other options like :dependent, :foreign_key might be added later)
      # @note Because every object needs friends, even if they're just proxies.
      def has_many(name, options = {})
        reflection = build_reflection(:has_many, name, options)
        add_reflection(name, reflection)

        if options[:through]
          define_has_many_through_reader(reflection)
          # TODO: Define writers/helpers for :through if applicable (often read-only, like your hopes)
        else
          define_has_many_methods(reflection)
        end
      end

      # Defines a many-to-one or one-to-one association where this model
      # is considered the "child" or holder of the reference.
      #
      # @param name [Symbol] The name of the association (e.g., :author).
      # @param options [Hash] Configuration options:
      #   - :class_name [String] The class name of the associated model (e.g., "Person").
      #     Defaults to the camelized name.
      #   - :relationship [String] The type of the graph relationship (e.g., "WROTE").
      #     Defaults to the upcased association name.
      #   - :direction [:in, :out, :both] The direction of the relationship relative to this model.
      #     Defaults to :out for belongs_to (meaning this node points OUT to the parent).
      #   - (Other options)
      # @note Because sometimes you just want to belong... to something, anything.
      def belongs_to(name, options = {})
        reflection = build_reflection(:belongs_to, name, options)
        add_reflection(name, reflection)
        define_belongs_to_methods(reflection)
      end

      # Defines a one-to-one association where this model is considered the "parent".
      #
      # @param name [Symbol] The name of the association (e.g., :profile).
      # @param options [Hash] Configuration options:
      #   - :class_name [String] The class name of the associated model (e.g., "UserProfile").
      #     Defaults to the camelized name.
      #   - :relationship [String] The type of the graph relationship (e.g., "HAS_PROFILE").
      #     Defaults to the upcased association name.
      #   - :direction [:in, :out, :both] The direction of the relationship relative to this model.
      #     Defaults to :out for has_one.
      #   - (Other options)
      # @note Because every object deserves a child it can ignore.
      def has_one(name, options = {})
        reflection = build_reflection(:has_one, name, options)
        add_reflection(name, reflection)
        define_has_one_methods(reflection)
      end

      private

      # Helper to build a reflection object (simple hash for now)
      # @note One day this will be a class. Today is not that day.
      def build_reflection(macro, name, options)
        options[:macro] = macro
        options[:name] = name
        options[:class_name] ||= name.to_s.camelize
        options[:relationship] ||= name.to_s.upcase
        options[:direction] ||= :out
        options[:relationship_class] = options[:relationship_class]&.to_s # Store as string if present
        # TODO: Introduce a proper Reflection class later if needed. Or not.
        options
      end

      # Stores the reflection metadata
      # Because nothing says "scalable" like a class variable.
      def add_reflection(name, reflection)
        self._reflections = _reflections.merge(name => reflection)
      end

      # --- Method Definition Helpers (Placeholders) ---

      # Defines the actual has_many reader method.
      # Because what you really wanted was a proxy for disappointment.
      def define_has_many_methods(reflection)
        name              = reflection[:name]          # e.g. :hobbies
        target_class_name = reflection[:class_name]    # "HobbyNode"
        rel_type          = reflection[:relationship]  # "ENJOYS"
        direction         = reflection[:direction]     # :out, :in, :both

        define_method(name) do
          unless persisted?
            raise ActiveCypher::PersistenceError,
                  'Association load attempted on unsaved record'
          end

          # Resolve the target node class
          target_class = target_class_name.constantize
          a_alias = :start
          b_alias = :target

          # Pattern nodes (immutable)
          a_node = Cyrel::Pattern::Node.new(a_alias, labels: self.class.label_name)
          b_node = Cyrel::Pattern::Node.new(b_alias, labels: target_class.label_name)

          # Relationship pattern with correct direction
          rel_direction = case direction
                          when :out  then Cyrel::Direction::OUT
                          when :in   then Cyrel::Direction::IN
                          else Cyrel::Direction::BOTH
                          end

          rel_node = Cyrel::Pattern::Relationship.new(
            types: rel_type,
            direction: rel_direction
          )

          # Build undirected / outgoing / incoming path
          path = case direction
                 when :in then Cyrel::Pattern::Path.new([b_node, rel_node, a_node])
                 else Cyrel::Pattern::Path.new([a_node, rel_node, b_node])
                 end

          # Compose query  MATCH – WHERE – RETURN
          query = Cyrel::Query.new
                              .match(path)
                              .where(Cyrel.node_id(a_alias).eq(internal_id))
                              .return_(b_alias)

          base_relation = Relation.new(target_class, query)

          # Return a collection proxy so callers can do owner.hobbies << chess, etc.
          Associations::CollectionProxy.new(self, reflection, base_relation)
        end
      end

      def define_belongs_to_methods(reflection)
        name              = reflection[:name]
        target_class_name = reflection[:class_name]
        rel_type          = reflection[:relationship]
        direction         = reflection[:direction] # :in, :out, :both

        # ------------------- reader -------------------------------------------
        define_method(name) do
          ivar = "@#{name}"
          return instance_variable_get(ivar) if instance_variable_defined?(ivar)

          unless persisted?
            raise ActiveCypher::PersistenceError,
                  'Association load attempted on unsaved record'
          end

          target_class = target_class_name.constantize
          a_alias = :a
          b_alias = :b

          # plain node patterns (no mutating helpers)
          a_node = Cyrel::Pattern::Node.new(a_alias, labels: self.class.label_name)
          b_node = Cyrel::Pattern::Node.new(b_alias, labels: target_class.label_name)

          # explicit relationship node – mirrors Arel::Nodes::Join construction
          rel = Cyrel::Pattern::Relationship.new(
            types: rel_type,
            direction: Cyrel::Direction::BOTH # undirected ‹--›
          )

          path = Cyrel::Pattern::Path.new([a_node, rel, b_node])

          query = Cyrel::Query.new
                              .match(path)
                              .where(Cyrel.node_id(a_alias).eq(internal_id))
                              .return_(b_alias)
                              .limit(1)

          relation = Relation.new(target_class, query)
          instance_variable_set(ivar, relation.first)
        end

        # Define writer (e.g., author=)
        define_method("#{name}=") do |associate|
          instance_var = "@#{name}"
          # Load current associate lazily only if needed for comparison or deletion
          current_associate = instance_variable_defined?(instance_var) ? instance_variable_get(instance_var) : nil
          # Load if not cached and persisted
          current_associate = public_send(name) if current_associate.nil? && persisted?

          # No change if assigning the same object
          return associate if associate == current_associate

          raise 'Cannot modify associations on a new record' unless persisted?

          # --- Delete existing relationship (if any) ---
          if current_associate
            del_start_alias = :a
            del_end_alias   = :b
            del_rel_alias   = :r
            cyrel_direction = if direction == :in
                                :out
                              else
                                (direction == :both ? :both : direction)
                              end

            del_query = Cyrel
                        .match(Cyrel.node(del_start_node.class.label_name).as(del_start_alias))
                        .match(Cyrel.node(del_end_node.class.label_name).as(del_end_alias))
                        .match(Cyrel.node(del_start_alias)
                                      .rel(cyrel_direction, rel_type)
                                      .as(del_rel_alias)
                                      .to(del_end_alias))
                        .where(Cyrel.node_id(del_start_alias).eq(del_start_node.internal_id))
                        .where(Cyrel.node_id(del_end_alias).eq(del_end_node.internal_id))
                        .delete(del_rel_alias)

            self.class.connection.execute_cypher(
              *del_query.to_cypher,
              'Delete Association (belongs_to)'
            )
          end

          # --- Create new relationship (if associate is not nil) ---
          if associate
            raise ArgumentError, "Associated object must be an instance of #{target_class_name}" unless associate.is_a?(target_class_name.constantize)
            raise "Associated object #{associate.inspect} must be persisted" unless associate.persisted?

            # Determine start/end nodes for creation based on direction
            new_start_node, new_end_node =
              case direction
              when :out then [self, associate]
              when :in   then [associate, self]
              when :both then [self, associate] # choose a deterministic orientation
              else raise ArgumentError,
                         "Direction '#{direction}' not supported for creation via '='"
              end

            if reflection[:relationship_class]
              # Use Relationship Model
              rel_model_class = reflection[:relationship_class].constantize
              # TODO: Extract relationship properties if passed somehow (e.g., via options hash?)
              rel_props = {}
              relationship_instance = rel_model_class.new(rel_props, from_node: new_start_node, to_node: new_end_node)
              relationship_instance.save # Relationship model handles Cypher generation
            else
              # Use direct Cypher generation
              new_start_alias = :a
              new_end_alias   = :b
              arrow           = direction == :both ? :both : :out

              create_query = Cyrel
                             .match(Cyrel.node(new_start_node.class.label_name).as(new_start_alias))
                             .match(Cyrel.node(new_end_node.class.label_name).as(new_end_alias))
                             .where(Cyrel.node_id(new_start_alias).eq(new_start_node.internal_id))
                             .where(Cyrel.node_id(new_end_alias).eq(new_end_node.internal_id))
                             .create(Cyrel.node(new_start_alias)
                                            .rel(arrow, rel_type)
                                            .to(new_end_alias))

              self.class.connection.execute_cypher(
                *create_query.to_cypher,
                'Create Association (belongs_to - Direct)'
              )
            end
          end

          # Update the instance variable cache
          instance_variable_set(instance_var, associate)
        end

        # Define build method (e.g., build_author(name: "New Author"))
        define_method("build_#{name}") do |attributes = {}|
          target_class = target_class_name.constantize
          # TODO: Potentially set the inverse association reference here
          # For now, just instantiate the target class
          target_class.new(attributes)
        end

        # Define create method (e.g., create_author(name: "New Author"))
        define_method("create_#{name}") do |attributes = {}|
          # Build the instance
          instance = public_send("build_#{name}", attributes)
          # Save the instance
          instance.save
          # If save is successful, associate it using the = method
          public_send("#{name}=", instance) if instance.persisted?
          # Return the instance
          instance
        end
      end

      def define_has_one_methods(reflection)
        name = reflection[:name]
        target_class_name = reflection[:class_name]
        rel_type = reflection[:relationship]
        direction = reflection[:direction] # :in, :out, :both

        # Define reader method (e.g., profile) - logic is same as belongs_to reader
        define_method(name) do
          instance_var = "@#{name}"
          return instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

          raise ActiveCypher::PersistenceError, 'Association load attempted on unsaved record' unless persisted?

          target_class = target_class_name.constantize
          start_node_alias = :start_node
          target_node_alias = :target_node

          start_node_pattern = Cyrel.node(self.class.label_name).as(start_node_alias)
                                    .where(Cyrel.node_id(start_node_alias).eq(internal_id))
          target_node_pattern = Cyrel.node(target_class.label_name).as(target_node_alias)

          rel_pattern = case direction
                        when :out
                          start_node_pattern.rel(:out, rel_type).to(target_node_pattern)
                        when :in
                          target_node_pattern.rel(:out, rel_type).to(start_node_pattern) # Reverse for Cyrel syntax
                        when :both
                          start_node_pattern.rel(:both, rel_type).to(target_node_pattern)
                        else
                          raise AssociationError, "Invalid direction: #{direction}"
                        end

          query = Cyrel.match(rel_pattern).return(target_node_alias).limit(1)

          relation = Relation.new(target_class, query)
          instance_variable_set(instance_var, relation.first)
        end

        # Define writer (e.g., profile=)
        define_method("#{name}=") do |associate|
          instance_var = "@#{name}"
          # Load current associate lazily only if needed for comparison or deletion
          current_associate = instance_variable_defined?(instance_var) ? instance_variable_get(instance_var) : nil
          # Load if not cached and persisted
          current_associate = public_send(name) if current_associate.nil? && persisted?

          # No change if assigning the same object
          return associate if associate == current_associate

          raise 'Cannot modify associations on a new record' unless persisted?

          # --- Delete existing relationship (if any) ---
          if current_associate
            # Determine start/end nodes for deletion based on direction
            del_start_node, del_end_node = case direction
                                           when :out then [self, current_associate]
                                           when :in then [current_associate, self]
                                           else raise ArgumentError,
                                                      "Direction '#{direction}' not supported for deletion via '='"
                                           end

            # Build Cyrel query to delete the relationship
            del_start_alias = :a
            del_end_alias = :b
            del_rel_alias = :r
            # Adjust direction for Cyrel pattern if needed
            cyrel_direction = direction == :in ? :out : direction
            del_query = Cyrel.match(Cyrel.node(del_start_node.class.label_name)
                                         .as(del_start_alias).where(Cyrel.node_id(del_start_alias)
                                                                         .eq(del_start_node.internal_id)))
                             .match(Cyrel.node(del_end_node.class.label_name)
                                         .as(del_end_alias).where(Cyrel.node_id(del_end_alias)
                                                                       .eq(del_end_node.internal_id)))
                             .match(Cyrel.node(del_start_alias).rel(cyrel_direction,
                                                                    rel_type).as(del_rel_alias).to(del_end_alias))
                             .delete(del_rel_alias)

            del_cypher = del_query.to_cypher
            del_params = { start_id: del_start_node.internal_id, end_id: del_end_node.internal_id }
            self.class.connection.execute_cypher(del_cypher, del_params, 'Delete Association (has_one)')
          end

          # --- Create new relationship (if associate is not nil) ---
          if associate
            raise ArgumentError, "Associated object must be an instance of #{target_class_name}" unless associate.is_a?(target_class_name.constantize)
            raise "Associated object #{associate.inspect} must be persisted" unless associate.persisted?

            # Determine start/end nodes for creation based on direction
            new_start_node, new_end_node = case direction
                                           when :out then [self, associate]
                                           when :in then [associate, self]
                                           else raise ArgumentError,
                                                      "Direction '#{direction}' not supported for creation via '='"
                                           end

            if reflection[:relationship_class]
              # Use Relationship Model
              rel_model_class = reflection[:relationship_class].constantize
              # TODO: Extract relationship properties if passed somehow
              rel_props = {}
              relationship_instance = rel_model_class.new(rel_props, from_node: new_start_node, to_node: new_end_node)
              relationship_instance.save
            else
              # Use direct Cypher generation
              new_start_alias = :a
              new_end_alias = :b
              create_query = Cyrel.match(Cyrel.node(new_start_node.class.label_name)
                                              .as(new_start_alias).where(Cyrel.node_id(new_start_alias)
                                                                              .eq(new_start_node.internal_id)))
                                  .match(Cyrel.node(new_end_node.class.label_name)
                                              .as(new_end_alias).where(Cyrel.node_id(new_end_alias)
                                                                            .eq(new_end_node.internal_id)))
                                  .create(Cyrel.node(new_start_alias).rel(:out, rel_type).to(new_end_alias))

              create_cypher = create_query.to_cypher
              create_params = { start_id: new_start_node.internal_id, end_id: new_end_node.internal_id }
              self.class.connection.execute_cypher(create_cypher, create_params,
                                                   'Create Association (has_one - Direct)')
            end
          end

          # Update the instance variable cache
          instance_variable_set(instance_var, associate)
        end

        # Define build method (e.g., build_profile(data: {...}))
        define_method("build_#{name}") do |attributes = {}|
          target_class = target_class_name.constantize
          # TODO: Potentially set the inverse association reference here
          # For now, just instantiate the target class
          target_class.new(attributes)
        end

        # Define create method (e.g., create_profile(data: {...}))
        define_method("create_#{name}") do |attributes = {}|
          # Build the instance
          instance = public_send("build_#{name}", attributes)
          # Save the instance
          instance.save
          # If save is successful, associate it using the = method
          public_send("#{name}=", instance) if instance.persisted?
          # Return the instance
          instance
        end
      end
    end

    # Defines the reader method for a has_many :through association.
    # Because sometimes you want to join tables, but with extra steps.
    def self.define_has_many_through_reader(reflection)
      name = reflection[:name]
      through_association_name = reflection[:through]
      source_association_name = reflection[:source] || name # Default source is same name on intermediate model

      define_method(name) do
        raise ActiveCypher::PersistenceError, 'Association load attempted on unsaved record' unless persisted?

        # 1. Get reflection for the intermediate association (e.g., :friendships)
        through_reflection = self.class._reflections[through_association_name]
        unless through_reflection
          raise ArgumentError,
                "Could not find association '#{through_association_name}' specified in :through option for '#{name}'"
        end

        intermediate_class = through_reflection[:class_name].constantize

        # 2. Get reflection for the source association on the intermediate model (e.g., :to_node on Friendship)
        # Note: This assumes the intermediate model also uses ActiveCypher::Associations
        source_reflection = intermediate_class._reflections[source_association_name]
        unless source_reflection
          raise ArgumentError,
                "Could not find association '#{source_association_name}' specified as :source (or inferred) on '#{intermediate_class.name}' for '#{name}'"
        end

        final_target_class = source_reflection[:class_name].constantize

        # 3. Build the multi-hop Cyrel query.
        # Because why settle for one hop when you can have two and still not get what you want?
        start_node_alias = :start_node
        intermediate_node_alias = :intermediate_node
        final_target_node_alias = :final_target

        # Start node pattern
        start_node_pattern = Cyrel.node(self.class.label_name).as(start_node_alias)
                                  .where(Cyrel.node_id(start_node_alias).eq(internal_id))

        # Intermediate node pattern (based on through_reflection)
        intermediate_node_pattern = Cyrel.node(intermediate_class.label_name).as(intermediate_node_alias)
        through_rel_type = through_reflection[:relationship]
        through_direction = through_reflection[:direction]

        first_hop_pattern = case through_direction
                            when :out then start_node_pattern.rel(:out, through_rel_type).to(intermediate_node_pattern)
                            when :in then intermediate_node_pattern.rel(:out, through_rel_type).to(start_node_pattern)
                            when :both then start_node_pattern.rel(:both,
                                                                   through_rel_type).to(intermediate_node_pattern)
                            else raise ArgumentError, "Invalid direction in through_reflection: #{through_direction}"
                            end

        # Final target node pattern (based on source_reflection)
        final_target_node_pattern = Cyrel.node(final_target_class.label_name).as(final_target_node_alias)
        source_rel_type = source_reflection[:relationship]
        source_direction = source_reflection[:direction]

        second_hop_pattern = case source_direction
                             when :out then intermediate_node_pattern.rel(:out,
                                                                          source_rel_type).to(final_target_node_pattern)
                             when :in then final_target_node_pattern.rel(:out,
                                                                         source_rel_type).to(intermediate_node_pattern)
                             when :both then intermediate_node_pattern.rel(:both,
                                                                           source_rel_type).to(final_target_node_pattern)
                             else raise ArgumentError, "Invalid direction in source_reflection: #{source_direction}"
                             end

        # Combine patterns and return final target
        # Assuming Cyrel allows chaining matches or building complex patterns
        # This might need adjustment based on Cyrel's exact path-building API
        query = Cyrel.match(first_hop_pattern)
                     .match(second_hop_pattern) # Assumes .match adds to the pattern
                     .return(final_target_node_alias)
        # TODO: Add DISTINCT if needed? .return(Cyrel.distinct(final_target_node_alias))

        # Return a Relation scoped to the final target class
        Relation.new(final_target_class, query)
      end
    end
  end
end
