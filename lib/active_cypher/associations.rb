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

    # Map a logical association direction to a Cyrel relationship direction.
    # @param direction [:in, :out, :both]
    # @return [Symbol] the corresponding Cyrel::Direction value
    def self.cyrel_direction(direction)
      case direction
      when :out then Cyrel::Direction::OUT
      when :in then Cyrel::Direction::IN
      when :both then Cyrel::Direction::BOTH
      else raise AssociationError, "Invalid direction: #{direction}"
      end
    end

    # A labelled node pattern pinned to a model class.
    # @param model_class [Class] the node model class
    # @param alias_name [Symbol] the pattern alias
    # @return [Cyrel::Pattern::Node]
    def self.node_pattern(model_class, alias_name)
      Cyrel::Pattern::Node.new(alias_name, labels: model_class.label_name)
    end

    # Build a (start)-[rel]->(end) path between two node patterns.
    # @param start_node [Cyrel::Pattern::Node] the "from" node pattern
    # @param end_node [Cyrel::Pattern::Node] the "to" node pattern
    # @param direction [:in, :out, :both] direction relative to start_node
    # @param rel_type [String, Symbol] the relationship type
    # @param rel_alias [Symbol, nil] optional alias for the relationship
    # @return [Cyrel::Pattern::Path]
    def self.relationship_path(start_node, end_node, direction, rel_type, rel_alias: nil)
      rel = Cyrel::Pattern::Relationship.new(alias_name: rel_alias, types: rel_type,
                                             direction: cyrel_direction(direction))
      Cyrel::Pattern::Path.new([start_node, rel, end_node])
    end

    # Build a query matching two nodes pinned by their internal ids, ready to
    # chain a further .match/.create/.delete_ onto. Cyrel orders clauses
    # canonically, so the trailing operation may be appended in any order.
    # @param start_node the model instance at the "from" end
    # @param start_alias [Symbol] alias for the start node
    # @param end_node the model instance at the "to" end
    # @param end_alias [Symbol] alias for the end node
    # @return [Cyrel::Query]
    def self.match_endpoints(start_node, start_alias, end_node, end_alias)
      Cyrel::Query.new
                  .match(node_pattern(start_node.class, start_alias))
                  .match(node_pattern(end_node.class, end_alias))
                  .where(Cyrel.node_id(start_alias).eq(start_node.internal_id))
                  .where(Cyrel.node_id(end_alias).eq(end_node.internal_id))
    end

    # Order a pair of endpoints by association direction.
    # @param receiver the model instance owning the association
    # @param other the associated model instance
    # @param direction [:in, :out, :both] direction relative to the receiver
    # @return [Array] [start_node, end_node]
    def self.ordered_endpoints(receiver, other, direction)
      case direction
      when :out, :both then [receiver, other]
      when :in then [other, receiver]
      else raise ArgumentError, "Direction '#{direction}' not supported for this operation"
      end
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

          owner_alias   = :start
          related_alias = :target

          # owner = the node we're querying from (self)
          # related = the node we want to fetch
          owner_node   = Cyrel::Pattern::Node.new(owner_alias,   labels: self.class.label_name)
          related_node = Cyrel::Pattern::Node.new(related_alias, labels: target_class.label_name)

          # The relationship token renders the arrow direction itself:
          #   :out  → -[:TYPE]->   e.g. (start:Person)-[:ENJOYS]->(target:Activity)
          #   :in   → <-[:TYPE]-   e.g. (start:Activity)<-[:ENJOYS]-(target:Person)
          #   :both → -[:TYPE]-    e.g. (start)-[:TYPE]-(target)
          # Node order is always [owner, rel, related] — never swapped.
          rel_direction = case direction
                          when :out  then Cyrel::Direction::OUT
                          when :in   then Cyrel::Direction::IN
                          else Cyrel::Direction::BOTH
                          end

          rel_node = Cyrel::Pattern::Relationship.new(
            types: rel_type,
            direction: rel_direction
          )

          path = Cyrel::Pattern::Path.new([owner_node, rel_node, related_node])

          # Compose query  MATCH – WHERE – RETURN
          query = Cyrel::Query.new
                              .match(path)
                              .where(Cyrel.node_id(owner_alias).eq(internal_id))
                              .return_(related_alias)

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
          start_alias = :start_node
          target_alias = :target # Relation#map_results only unwraps the :n or :target alias

          # belongs_to matches the relationship undirected (‹--›), regardless of declared direction
          path = Associations.relationship_path(
            Associations.node_pattern(self.class, start_alias),
            Associations.node_pattern(target_class, target_alias),
            :both, rel_type
          )

          query = Cyrel::Query.new
                              .match(path)
                              .where(Cyrel.node_id(start_alias).eq(internal_id))
                              .return_(target_alias)
                              .limit(1)

          relation = Relation.new(target_class, query)
          instance_variable_set(ivar, relation.first)
        end

        # Define writer (e.g., author=)
        define_singular_writer(name, target_class_name, rel_type, direction, reflection)

        define_build_and_create_methods(name, target_class_name)
      end

      # Defines build_<name> and create_<name> for singular associations
      # (shared by belongs_to and has_one).
      def define_build_and_create_methods(name, target_class_name)
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

      # Defines the writer (name=) for a singular association (has_one / belongs_to).
      # Both macros build the same delete-then-create Cypher; only the log label,
      # taken from reflection[:macro], differs.
      def define_singular_writer(name, target_class_name, rel_type, direction, reflection)
        macro = reflection[:macro]

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
            del_start_node, del_end_node = Associations.ordered_endpoints(self, current_associate, direction)
            del_arrow = direction == :both ? :both : :out
            del_query = Associations.match_endpoints(del_start_node, :a, del_end_node, :b)
                                    .match(Associations.relationship_path(
                                             Cyrel::Pattern::Node.new(:a), Cyrel::Pattern::Node.new(:b),
                                             del_arrow, rel_type, rel_alias: :r
                                           ))
                                    .delete_(:r)
            self.class.connection.execute_cypher(*del_query.to_cypher, "Delete Association (#{macro})")
          end

          # --- Create new relationship (if associate is not nil) ---
          if associate
            raise ArgumentError, "Associated object must be an instance of #{target_class_name}" unless associate.is_a?(target_class_name.constantize)
            raise "Associated object #{associate.inspect} must be persisted" unless associate.persisted?

            new_start_node, new_end_node = Associations.ordered_endpoints(self, associate, direction)

            if reflection[:relationship_class]
              # Use Relationship Model
              rel_model_class = reflection[:relationship_class].constantize
              relationship_instance = rel_model_class.new({}, from_node: new_start_node, to_node: new_end_node)
              relationship_instance.save # Relationship model handles Cypher generation
            else
              # Use direct Cypher generation
              create_query = Associations.match_endpoints(new_start_node, :a, new_end_node, :b)
                                         .create(Associations.relationship_path(
                                                   Cyrel::Pattern::Node.new(:a), Cyrel::Pattern::Node.new(:b),
                                                   :out, rel_type
                                                 ))
              self.class.connection.execute_cypher(*create_query.to_cypher, "Create Association (#{macro} - Direct)")
            end
          end

          # Update the instance variable cache
          instance_variable_set(instance_var, associate)
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
          start_alias = :start_node
          target_alias = :target # Relation#map_results only unwraps the :n or :target alias

          path = Associations.relationship_path(
            Associations.node_pattern(self.class, start_alias),
            Associations.node_pattern(target_class, target_alias),
            direction, rel_type
          )

          query = Cyrel::Query.new
                              .match(path)
                              .where(Cyrel.node_id(start_alias).eq(internal_id))
                              .return_(target_alias)
                              .limit(1)

          relation = Relation.new(target_class, query)
          instance_variable_set(instance_var, relation.first)
        end

        # Define writer (e.g., profile=)
        define_singular_writer(name, target_class_name, rel_type, direction, reflection)

        define_build_and_create_methods(name, target_class_name)
      end

      # Defines the reader method for a has_many :through association.
      # Because sometimes you want to join tables, but with extra steps.
      def define_has_many_through_reader(reflection)
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
          start_alias = :start_node
          intermediate_alias = :intermediate_node
          final_target_alias = :target # Relation#map_results only unwraps the :n or :target alias

          # The intermediate node pattern is shared by both hops so the aliases line up:
          #   MATCH (start)-[:THROUGH]->(intermediate) MATCH (intermediate)-[:SOURCE]->(final)
          start_node = Associations.node_pattern(self.class, start_alias)
          intermediate_node = Associations.node_pattern(intermediate_class, intermediate_alias)
          final_target_node = Associations.node_pattern(final_target_class, final_target_alias)

          first_hop = Associations.relationship_path(start_node, intermediate_node,
                                                     through_reflection[:direction], through_reflection[:relationship])
          second_hop = Associations.relationship_path(intermediate_node, final_target_node,
                                                      source_reflection[:direction], source_reflection[:relationship])

          query = Cyrel::Query.new
                              .match(first_hop)
                              .match(second_hop)
                              .where(Cyrel.node_id(start_alias).eq(internal_id))
                              .return_(final_target_alias)

          # Return a Relation scoped to the final target class
          Relation.new(final_target_class, query)
        end
      end
    end
  end
end
