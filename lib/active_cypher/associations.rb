# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/core_ext/string/inflections' # for camelize, singularize etc.

module ActiveCypher
  # Module to handle association definitions (has_many, belongs_to, etc.)
  # for ActiveCypher models.
  module Associations
    extend ActiveSupport::Concern

    included do
      # Storage for association reflection metadata on the class
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
      def has_many(name, options = {})
        reflection = build_reflection(:has_many, name, options)
        add_reflection(name, reflection)

        if options[:through]
          define_has_many_through_reader(reflection)
          # TODO: Define writers/helpers for :through if applicable (often read-only)
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
      def has_one(name, options = {})
        reflection = build_reflection(:has_one, name, options)
        add_reflection(name, reflection)
        define_has_one_methods(reflection)
      end

      private

      # Helper to build a reflection object (simple hash for now)
      def build_reflection(macro, name, options)
        options[:macro] = macro
        options[:name] = name
        options[:class_name] ||= name.to_s.camelize
        options[:relationship] ||= name.to_s.upcase
        options[:direction] ||= :out
        options[:relationship_class] = options[:relationship_class]&.to_s # Store as string if present
        # TODO: Introduce a proper Reflection class later if needed
        options.freeze # Make it immutable
      end

      # Stores the reflection metadata
      def add_reflection(name, reflection)
        self._reflections = _reflections.merge(name => reflection)
      end

      # --- Method Definition Helpers (Placeholders) ---

      def define_has_many_methods(reflection)
        name = reflection[:name]
        target_class_name = reflection[:class_name]
        rel_type = reflection[:relationship]
        direction = reflection[:direction] # :in, :out, :both

        # Define reader method (e.g., posts)
        define_method(name) do
          raise 'Cannot query associations on a new record' unless persisted?

          target_class = target_class_name.constantize
          start_node_alias = :start_node
          target_node_alias = :target_node

          # Build the Cyrel query pattern based on direction
          start_node_pattern = Cyrel.node(self.class.label_name).as(start_node_alias)
                                    .where(Cyrel.id(start_node_alias).eq(internal_id)) # Match current node by ID

          target_node_pattern = Cyrel.node(target_class.label_name).as(target_node_alias)

          # Define relationship pattern based on direction
          rel_pattern = case direction
                        when :out
                          start_node_pattern.rel(:out, rel_type).to(target_node_pattern)
                        when :in
                          target_node_pattern.rel(:out, rel_type).to(start_node_pattern) # Reverse for Cyrel syntax
                        when :both
                          start_node_pattern.rel(:both, rel_type).to(target_node_pattern)
                        else
                          raise ArgumentError, "Invalid direction: #{direction}"
                        end

          # Construct the full query
          query = Cyrel.match(rel_pattern).return(target_node_alias)

          # Return a Relation scoped to the target class with the specific query
          Relation.new(target_class, query)
        end

        # TODO: Implement other methods like <<, _ids, _ids=, build, create
        # Define adder method (e.g., posts << other_post)
        define_method('<<') do |*associates_with_props|
          raise 'Cannot modify associations on a new record' unless persisted?

          # Allow passing properties for the relationship model, e.g., user.friendships.create(to_node: friend, since: Date.today)
          # or user.friends << [friend, {since: Date.today}]
          # For now, handle simple case: user.friends << friend
          # TODO: Enhance to handle properties passed alongside the associate

          associates = associates_with_props.flatten.compact # Simple extraction for now

          associates.each do |associate|
            unless associate.is_a?(target_class_name.constantize)
              raise ArgumentError, "Associated object must be an instance of #{target_class_name}"
            end
            raise "Associated object #{associate.inspect} must be persisted" unless associate.persisted?

            # Determine start and end nodes based on direction
            start_node, end_node = case direction
                                   when :out then [self, associate]
                                   when :in then [associate, self]
                                   else raise ArgumentError,
                                              "Direction '#{direction}' not supported for creation via '<<'"
                                   end

            if reflection[:relationship_class]
              # Use Relationship Model
              rel_model_class = reflection[:relationship_class].constantize
              # TODO: Extract relationship properties if passed in associates_with_props
              rel_props = {}
              relationship_instance = rel_model_class.new(rel_props, from_node: start_node, to_node: end_node)
              relationship_instance.save # Relationship model handles Cypher generation
            else
              # Use direct Cypher generation (simple relationship)
              start_alias = :a
              end_alias = :b
              query = Cyrel.match(Cyrel.node(start_node.class.label_name).as(start_alias).where(Cyrel.id(start_alias).eq(start_node.internal_id)))
                           .match(Cyrel.node(end_node.class.label_name).as(end_alias).where(Cyrel.id(end_alias).eq(end_node.internal_id)))
                           .create(Cyrel.node(start_alias).rel(:out, rel_type).to(end_alias)) # Assuming Cyrel.create handles MERGE implicitly or we use MERGE

              cypher = query.to_cypher
              params = { start_id: start_node.internal_id, end_id: end_node.internal_id } # Adjust params based on Cyrel needs
              self.class.connection.execute_cypher(cypher, params, 'Create Association (Direct)')
            end
          end
          # TODO: Invalidate association cache if implemented
          self # Return self for chaining
        end

        # Define ID reader (e.g., post_ids)
        define_method("#{name.to_s.singularize}_ids") do
          # Optimization: Could potentially fetch only IDs
          public_send(name).map(&:internal_id) # Simple implementation using the reader
        end

        # Define ID writer (e.g., post_ids=)
        define_method("#{name.to_s.singularize}_ids=") do |ids|
          # TODO: Implement replacing associations by IDs
          # Needs logic to find current associated IDs, compare with new IDs,
          # delete removed relationships, and create added relationships.
        end

        # Define build method (e.g., build_post(name: "New Post"))
        # Instantiates a new object of the associated class.
        # Does not automatically save or create the relationship yet.
        define_method("build_#{name.to_s.singularize}") do |attributes = {}|
          target_class = target_class_name.constantize
          # TODO: Potentially set the inverse association reference here if applicable
          # e.g., new_post.author = self (if inverse_of is defined)
          # For now, just instantiate the target class
          target_class.new(attributes)
        end
        # Define create method (e.g., create_post(name: "New Post"))
        # Instantiates, saves, and associates the new object.
        define_method("create_#{name.to_s.singularize}") do |attributes = {}|
          # Build the instance using the build_* method
          instance = public_send("build_#{name.to_s.singularize}", attributes)
          # Save the instance first
          instance.save
          # If save is successful, associate it using the << method
          public_send('<<', instance) if instance.persisted?
          # Return the (potentially unsaved if validations failed) instance
          instance
        end
      end

      def define_belongs_to_methods(reflection)
        name = reflection[:name]
        target_class_name = reflection[:class_name]
        rel_type = reflection[:relationship]
        direction = reflection[:direction] # :in, :out, :both

        # Define reader method (e.g., profile) - logic is same as belongs_to reader
        define_method(name) do
          instance_var = "@#{name}"
          return instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

          raise 'Cannot query associations on a new record' unless persisted?

          target_class = target_class_name.constantize
          start_node_alias = :start_node
          target_node_alias = :target_node

          start_node_pattern = Cyrel.node(self.class.label_name).as(start_node_alias)
                                    .where(Cyrel.id(start_node_alias).eq(internal_id))
          target_node_pattern = Cyrel.node(target_class.label_name).as(target_node_alias)

          rel_pattern = case direction
                        when :out
                          start_node_pattern.rel(:out, rel_type).to(target_node_pattern)
                        when :in
                          target_node_pattern.rel(:out, rel_type).to(start_node_pattern)
                        when :both
                          start_node_pattern.rel(:both, rel_type).to(target_node_pattern)
                        else
                          raise ArgumentError, "Invalid direction: #{direction}"
                        end

          query = Cyrel.match(rel_pattern).return(target_node_alias).limit(1)

          relation = Relation.new(target_class, query)
          instance_variable_set(instance_var, relation.first)
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
            # Adjust direction for Cyrel pattern if needed (Cyrel might expect :out/:in based on pattern structure)
            cyrel_direction = direction == :in ? :out : direction
            del_query = Cyrel.match(Cyrel.node(del_start_node.class.label_name).as(del_start_alias).where(Cyrel.id(del_start_alias).eq(del_start_node.internal_id)))
                             .match(Cyrel.node(del_end_node.class.label_name).as(del_end_alias).where(Cyrel.id(del_end_alias).eq(del_end_node.internal_id)))
                             .match(Cyrel.node(del_start_alias).rel(cyrel_direction,
                                                                    rel_type).as(del_rel_alias).to(del_end_alias))
                             .delete(del_rel_alias) # Assuming Cyrel.delete works on rel alias

            del_cypher = del_query.to_cypher
            del_params = { start_id: del_start_node.internal_id, end_id: del_end_node.internal_id }
            self.class.connection.execute_cypher(del_cypher, del_params, 'Delete Association (belongs_to)')
          end

          # --- Create new relationship (if associate is not nil) ---
          if associate
            unless associate.is_a?(target_class_name.constantize)
              raise ArgumentError, "Associated object must be an instance of #{target_class_name}"
            end
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
              # TODO: Extract relationship properties if passed somehow (e.g., via options hash?)
              rel_props = {}
              relationship_instance = rel_model_class.new(rel_props, from_node: new_start_node, to_node: new_end_node)
              relationship_instance.save # Relationship model handles Cypher generation
            else
              # Use direct Cypher generation
              new_start_alias = :a
              new_end_alias = :b
              create_query = Cyrel.match(Cyrel.node(new_start_node.class.label_name).as(new_start_alias).where(Cyrel.id(new_start_alias).eq(new_start_node.internal_id)))
                                  .match(Cyrel.node(new_end_node.class.label_name).as(new_end_alias).where(Cyrel.id(new_end_alias).eq(new_end_node.internal_id)))
                                  .create(Cyrel.node(new_start_alias).rel(:out, rel_type).to(new_end_alias)) # Create relationship

              create_cypher = create_query.to_cypher
              create_params = { start_id: new_start_node.internal_id, end_id: new_end_node.internal_id }
              self.class.connection.execute_cypher(create_cypher, create_params,
                                                   'Create Association (belongs_to - Direct)')
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

          raise 'Cannot query associations on a new record' unless persisted?

          target_class = target_class_name.constantize
          start_node_alias = :start_node
          target_node_alias = :target_node

          start_node_pattern = Cyrel.node(self.class.label_name).as(start_node_alias)
                                    .where(Cyrel.id(start_node_alias).eq(internal_id))
          target_node_pattern = Cyrel.node(target_class.label_name).as(target_node_alias)

          rel_pattern = case direction
                        when :out
                          start_node_pattern.rel(:out, rel_type).to(target_node_pattern)
                        when :in
                          target_node_pattern.rel(:out, rel_type).to(start_node_pattern) # Reverse for Cyrel syntax
                        when :both
                          start_node_pattern.rel(:both, rel_type).to(target_node_pattern)
                        else
                          raise ArgumentError, "Invalid direction: #{direction}"
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
            del_query = Cyrel.match(Cyrel.node(del_start_node.class.label_name).as(del_start_alias).where(Cyrel.id(del_start_alias).eq(del_start_node.internal_id)))
                             .match(Cyrel.node(del_end_node.class.label_name).as(del_end_alias).where(Cyrel.id(del_end_alias).eq(del_end_node.internal_id)))
                             .match(Cyrel.node(del_start_alias).rel(cyrel_direction,
                                                                    rel_type).as(del_rel_alias).to(del_end_alias))
                             .delete(del_rel_alias)

            del_cypher = del_query.to_cypher
            del_params = { start_id: del_start_node.internal_id, end_id: del_end_node.internal_id }
            self.class.connection.execute_cypher(del_cypher, del_params, 'Delete Association (has_one)')
          end

          # --- Create new relationship (if associate is not nil) ---
          if associate
            unless associate.is_a?(target_class_name.constantize)
              raise ArgumentError, "Associated object must be an instance of #{target_class_name}"
            end
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
              create_query = Cyrel.match(Cyrel.node(new_start_node.class.label_name).as(new_start_alias).where(Cyrel.id(new_start_alias).eq(new_start_node.internal_id)))
                                  .match(Cyrel.node(new_end_node.class.label_name).as(new_end_alias).where(Cyrel.id(new_end_alias).eq(new_end_node.internal_id)))
                                  .create(Cyrel.node(new_start_alias).rel(:out, rel_type).to(new_end_alias)) # Create relationship

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
    def self.define_has_many_through_reader(reflection)
      name = reflection[:name]
      through_association_name = reflection[:through]
      source_association_name = reflection[:source] || name # Default source is same name on intermediate model

      define_method(name) do
        raise 'Cannot query associations on a new record' unless persisted?

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

        # 3. Build the multi-hop Cyrel query
        start_node_alias = :start_node
        intermediate_node_alias = :intermediate_node
        final_target_node_alias = :final_target

        # Start node pattern
        start_node_pattern = Cyrel.node(self.class.label_name).as(start_node_alias)
                                  .where(Cyrel.id(start_node_alias).eq(internal_id))

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
