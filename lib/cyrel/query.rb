# frozen_string_literal: true

# Base DSL components
require 'cyrel/parameterizable'
require 'cyrel/logging'

# Require all clause types for DSL methods

module Cyrel
  # Error raised when merging queries with conflicting alias definitions.
  # Because even in graphs, two things can't have the same name without drama.
  class AliasConflictError < StandardError
    def initialize(alias_name, query1_details, query2_details)
      super("Alias conflict for ':#{alias_name}'. Query 1 defines it as #{query1_details}, Query 2 defines it as #{query2_details}.")
    end
  end

  # @!parse
  #   # The Cyrel Query class: where all your hopes, dreams, and clauses go to be awkwardly merged.
  #   # Manages clauses, parameters, and final query generation, because string interpolation is for amateurs.
  class Query
    include Parameterizable
    include Logging
    attr_reader :parameters, :clauses # Expose clauses for merge logic

    def initialize
      @parameters = {}
      @param_counter = 0
      @clauses = [] # Holds instances of Clause::Base subclasses, because arrays are the new query planner
    end

    # Registers a value and returns a parameter key.
    # Think of it as variable adoption but with less paperwork and more risk.
    # @param value [Object] The value to parameterize.
    # @return [Symbol] The parameter key (e.g., :p1, :p2).
    # Because nothing says "safe query" like a parade of anonymous parameters.
    def register_parameter(value)
      existing_key = @parameters.key(value)
      return existing_key if existing_key

      key = next_param_key
      @parameters[key] = value
      key
    end

    # Adds a clause object to the query.
    # @param clause [Cyrel::Clause::Base] The clause instance to add.
    # Because what you really wanted was a linked list of existential dread.
    def add_clause(clause)
      @clauses << clause
      self # Allow chaining
    end

    # Generates the final Cypher query string and parameters hash.
    # @return [Array(String, Hash)] The Cypher string and parameters.
    # This is where all your careful planning gets flattened into a string.
    def to_cypher
      ActiveSupport::Notifications.instrument('cyrel.render', query: self) do
        cypher_string = @clauses
                        .map { it.render(self) }
                        .reject(&:blank?)
                        .join("\n")

        log_debug("QUERY: #{cypher_string}")
        log_debug("PARAMS: #{@parameters.inspect}") unless @parameters.empty?

        [cypher_string, @parameters]
      end
    end

    # Merges two Cyrel::Query objects together.
    # Think Cypher polyamory: full of unexpected alias drama and parameter custody battles.
    # @param other_query [Cyrel::Query] The query to merge in.
    # @return [self]
    # If you like surprises, you'll love this method.
    def merge!(other_query)
      raise ArgumentError, 'Can only merge another Cyrel::Query' unless other_query.is_a?(Cyrel::Query)
      return self if other_query.clauses.empty? # Nothing to merge

      # 1. Alias Conflict Detection
      check_alias_conflicts!(other_query)

      # 2. Parameter Merging
      merge_parameters!(other_query)

      # 3. Clause Combination
      combine_clauses!(other_query)

      self
    end
    # --- DSL Methods ---

    # Adds a MATCH clause.
    # @param pattern [Cyrel::Pattern::Path, Node, Relationship, Hash, Array] Pattern definition.
    #   - Can pass Pattern objects directly.
    #   - Can pass Hashes/Arrays to construct simple Node/Relationship patterns implicitly? (TBD)
    # @param path_variable [Symbol, String, nil] Optional variable for the path.
    # @return [self]
    # Because nothing says "find me" like a declarative pattern and a prayer.
    def match(pattern, path_variable: nil)
      # TODO: Add implicit pattern construction from Hash/Array if desired.
      add_clause(Clause::Match.new(pattern, optional: false, path_variable: path_variable))
    end

    # Adds an OPTIONAL MATCH clause.
    # @param pattern [Cyrel::Pattern::Path, Node, Relationship, Hash, Array] Pattern definition.
    # @param path_variable [Symbol, String, nil] Optional variable for the path.
    # @return [self]
    # For when you want to be non-committal, even in your queries.
    def optional_match(pattern, path_variable: nil)
      add_clause(Clause::Match.new(pattern, optional: true, path_variable: path_variable))
    end

    # Adds a WHERE clause (merging with an existing one if present).
    #
    # @example
    #   query.where(name: 'Alice').where(age: 30)
    #   # ⇒ WHERE ((n.name = $p1) AND (n.age = $p2))
    #
    # Accepts:
    #   • Hash  – coerced into equality comparisons
    #   • Cyrel::Expression instances (or anything Expression.coerce understands)
    #
    # @return [self]
    # Because sometimes you want to filter, and sometimes you just want to judge.
    def where(*conditions)
      # ------------------------------------------------------------------
      # 1. Coerce incoming objects into Cyrel::Expression instances
      # ------------------------------------------------------------------
      processed_conditions = conditions.flat_map do |cond|
        if cond.is_a?(Hash)
          cond.map do |key, value|
            Expression::Comparison.new(
              Expression::PropertyAccess.new(@current_alias || infer_alias, key),
              :'=',
              value
            )
          end
        else
          cond # already an expression (or coercible)
        end
      end

      new_where = Clause::Where.new(*processed_conditions)

      # ------------------------------------------------------------------
      # 2. Merge with an existing WHERE (if any)
      # ------------------------------------------------------------------
      existing_where = @clauses.find { |c| c.is_a?(Clause::Where) }
      if existing_where
        existing_where.merge!(new_where)
        return self
      end

      # ------------------------------------------------------------------
      # 3. Determine correct insertion point
      # ------------------------------------------------------------------
      insertion_index = @clauses.index do |c|
        c.is_a?(Clause::Return) ||
          c.is_a?(Clause::OrderBy) ||
          c.is_a?(Clause::Skip)    ||
          c.is_a?(Clause::Limit)
      end

      if insertion_index
        @clauses.insert(insertion_index, new_where)
      else
        @clauses << new_where
      end

      self
    end

    # Adds a CREATE clause.
    # @param pattern [Cyrel::Pattern::Path, Node, Relationship, Hash, Array] Pattern definition.
    # @return [self]
    # Because sometimes you want to make things, not just break them.
    def create(pattern)
      # TODO: Add implicit pattern construction
      add_clause(Clause::Create.new(pattern))
    end

    # Adds a MERGE clause.
    # @param pattern [Cyrel::Pattern::Path, Node, Relationship, Hash, Array] Pattern definition.
    # @return [self]
    # For when you want to find-or-create, but with more existential angst.
    def merge(pattern)
      # TODO: Add implicit pattern construction
      # TODO: Add ON CREATE SET / ON MATCH SET options
      add_clause(Clause::Merge.new(pattern))
    end

    # Adds a SET clause.
    # @param assignments [Hash, Array] See Clause::Set#initialize.
    # @return [self]
    # Because sometimes you just want to change everything and pretend it was always that way.
    def set(assignments)
      # TODO: Consider merging SET clauses intelligently if needed.
      add_clause(Clause::Set.new(assignments))
    end

    # Adds a REMOVE clause.
    # @param items [Array<Cyrel::Expression::PropertyAccess, Array>] See Clause::Remove#initialize.
    # @return [self]
    # For when you want to Marie Kondo your graph.
    def remove(*items)
      # TODO: Consider merging REMOVE clauses.
      add_clause(Clause::Remove.new(items)) # Pass array directly
    end

    # Adds a DELETE clause. Use `detach_delete` for DETACH DELETE.
    # @param variables [Array<Symbol, String>] Variables to delete.
    # @return [self]
    # Underscore to avoid keyword clash
    # Because sometimes you just want to watch the world burn, one node at a time.
    def delete_(*variables)
      add_clause(Clause::Delete.new(*variables, detach: false))
    end

    # Adds a DETACH DELETE clause.
    # @param variables [Array<Symbol, String>] Variables to delete.
    # @return [self]
    # For when you want to delete with extreme prejudice.
    def detach_delete(*variables)
      add_clause(Clause::Delete.new(*variables, detach: true))
    end

    # Adds a WITH clause.
    # @param items [Array] Items to project. See Clause::With#initialize.
    # @param distinct [Boolean] Use DISTINCT?
    # @param where [Cyrel::Clause::Where, Hash, Array] Optional WHERE condition(s) after WITH.
    # @return [self]
    # Because sometimes you want to pass things along, and sometimes you just want to pass the buck.
    def with(*items, distinct: false, where: nil)
      where_clause = case where
                     when Clause::Where then where
                     when nil then nil
                     else Clause::Where.new(*Array(where)) # Coerce Hash/Array/Expression
                     end
      add_clause(Clause::With.new(*items, distinct: distinct, where: where_clause))
    end

    # Adds a RETURN clause.
    # @param items [Array] Items to return. See Clause::Return#initialize.
    # @param distinct [Boolean] Use DISTINCT?
    # @return [self]
    # Underscore to avoid keyword clash
    # Because what you really want is your data, but what you'll get is a hash.
    def return_(*items, distinct: false)
      # TODO: Consider merging RETURN clauses?
      add_clause(Clause::Return.new(*items, distinct: distinct))
    end

    # Adds or replaces the ORDER BY clause.
    # @param order_items [Array<Array>, Hash] Ordering specifications.
    #   - Array: [[expr, :asc], [expr, :desc], ...]
    #   - Hash: { expr => :asc, expr => :desc, ... }
    # @return [self]
    # Because sometimes you want order, and sometimes you just want chaos.
    def order_by(*order_items)
      items_array = order_items.first.is_a?(Hash) ? order_items.first.to_a : order_items

      existing_order = @clauses.find { |c| c.is_a?(Clause::OrderBy) }
      new_order = Clause::OrderBy.new(*items_array)
      if existing_order
        existing_order.replace!(new_order)
      else
        add_clause(new_order)
      end
      self
    end

    # Adds or replaces the SKIP clause.
    # @param amount [Integer, Expression] Number of results to skip.
    # @return [self]
    # For when you want to ignore the first N results, just like your unread emails.
    def skip(amount)
      existing_skip = @clauses.find { |c| c.is_a?(Clause::Skip) }
      new_skip = Clause::Skip.new(amount)
      if existing_skip
        existing_skip.replace!(new_skip)
      else
        add_clause(new_skip)
      end
      self
    end

    # Adds or replaces the LIMIT clause.
    # @param amount [Integer, Expression] Maximum number of results.
    # @return [self]
    # Because sometimes you want boundaries, even in your queries.
    def limit(amount)
      existing_limit = @clauses.find { |c| c.is_a?(Clause::Limit) }
      new_limit = Clause::Limit.new(amount)
      if existing_limit
        existing_limit.replace!(new_limit)
      else
        add_clause(new_limit)
      end
      self
    end

    # Adds a CALL procedure clause.
    # @param procedure_name [String] Name of the procedure.
    # @param arguments [Array] Arguments for the procedure.
    # @param yield_items [Array<String>, String, nil] Items to YIELD.
    # @param where [Clause::Where, Hash, Array, nil] WHERE condition after YIELD.
    # @param return_items [Clause::Return, Array, nil] RETURN items after WHERE/YIELD.
    # @return [self]
    # For when you want to call a procedure and pretend it's not just another query.
    def call_procedure(procedure_name, arguments: [], yield_items: nil, where: nil, return_items: nil)
      add_clause(Clause::Call.new(procedure_name,
                                  arguments: arguments,
                                  yield_items: yield_items,
                                  where: where,
                                  return_items: return_items))
    end

    # Adds a CALL { subquery } clause.
    # @yield [Cyrel::Query] Yields a new query object for building the subquery.
    # @return [self]
    # Because why write one query when you can write two and glue them together?
    def call_subquery
      subquery = Cyrel::Query.new
      yield subquery
      # Important: Parameters defined within the subquery block are currently
      # NOT automatically merged into the outer query's parameters by this DSL method.
      # This needs to be handled either by manually merging parameters after the block
      # or by enhancing the rendering/parameter registration logic.
      add_clause(Clause::CallSubquery.new(subquery))
      # Consider adding: merge_parameters!(subquery) here, but it might re-register params.
    end

    # No longer private, needed by merge!
    # private

    # Merges parameters from another query, ensuring keys are unique.
    # Because parameter collisions are the only collisions you want in production.
    def merge_parameters!(other_query)
      # Ensure our counter is beyond the other query's potential keys
      max_other_param_num = other_query.parameters.keys
                                       .map { |k| k.to_s.sub(/^p/, '').to_i }
                                       .max || 0
      @param_counter = [@param_counter, max_other_param_num].max

      # Re-register each parameter from the other query
      other_query.parameters.each_value do |value|
        register_parameter(value)
        # NOTE: This doesn't update references within the other_query's original clauses.
      end
    end

    # Provides a sort order for clauses during rendering. Lower numbers come first.
    # Because even your clauses need to know their place in the world.
    def clause_order(clause)
      case clause
      when Clause::Match, Clause::Create, Clause::Merge then 10 # Reading/Writing/Merging clauses
      when Clause::Call, Clause::CallSubquery then 15 # CALL often follows MATCH/CREATE
      when Clause::With then 20
      when Clause::Where then 30 # Filtering clauses
      when Clause::Set, Clause::Remove, Clause::Delete then 40 # Modifying clauses
      when Clause::Return then 50 # Projection
      when Clause::OrderBy then 60 # Ordering/Paging
      when Clause::Skip then 70
      when Clause::Limit then 80
      else 99 # Unknown clauses go last
      end
    end

    # Extracts defined aliases and their labels from the query's clauses.
    # @return [Hash{Symbol => Set<String>}] { alias_name => Set[label1, label2] }
    # Because even your variables want to be unique snowflakes.
    def defined_aliases
      aliases = {}
      @clauses.each do |clause|
        # Look for clauses that define patterns (Match, Create, Merge)
        next unless clause.respond_to?(:pattern) && clause.pattern

        elements_to_check = []
        case clause.pattern
        when Pattern::Path
          elements_to_check.concat(clause.pattern.elements)
        when Pattern::Node, Pattern::Relationship
          elements_to_check << clause.pattern
        end

        elements_to_check.each do |element|
          next unless element.respond_to?(:alias_name) && element.alias_name

          alias_name = element.alias_name
          labels = Set.new
          labels.merge(element.labels) if element.is_a?(Pattern::Node) && element.respond_to?(:labels)

          aliases[alias_name] ||= Set.new
          aliases[alias_name].merge(labels) unless labels.empty?
        end
      end
      aliases
    end

    # Detects alias conflicts between queries.
    # Because two nodes with the same name but different labels are the graph equivalent of identity theft.
    def check_alias_conflicts!(other_query)
      self_aliases = defined_aliases
      other_aliases = other_query.defined_aliases

      conflicting_aliases = self_aliases.keys & other_aliases.keys

      conflicting_aliases.each do |alias_name|
        self_labels = self_aliases[alias_name]
        other_labels = other_aliases[alias_name]

        # Conflict if labels are defined and different, or if one defines labels and the other doesn't.
        # Allowing merge if both define the *same* labels or neither defines labels.
        is_conflict = !self_labels.empty? && !other_labels.empty? && self_labels != other_labels
        # Consider it a conflict if one defines labels and the other doesn't? Maybe too strict.
        # is_conflict ||= (self_labels.empty? != other_labels.empty?)

        next unless is_conflict

        raise AliasConflictError.new(
          alias_name,
          "labels #{self_labels.to_a.inspect}",
          "labels #{other_labels.to_a.inspect}"
        )
      end
    end

    # Combines clauses from the other query into this one based on type.
    # Because merging queries is just like merging companies: someone always loses.
    def combine_clauses!(other_query)
      # Clone other query's clauses to avoid modifying it during iteration
      other_clauses_to_process = other_query.clauses.dup

      # --- Handle Replacing Clauses (OrderBy, Skip, Limit) ---
      [Clause::OrderBy, Clause::Skip, Clause::Limit].each do |clause_class|
        # Find the last occurrence in the other query's clauses
        other_clause = other_clauses_to_process.reverse.find { |c| c.is_a?(clause_class) }
        next unless other_clause

        # Find the clause in self, if it exists
        self_clause = @clauses.find { |c| c.is_a?(clause_class) }

        if self_clause.respond_to?(:replace!)
          # If self has the clause and it supports replace!, replace it
          self_clause.replace!(other_clause)
        elsif !self_clause
          # If self doesn't have the clause, add the one from other_query
          add_clause(other_clause)
          # Else: self has the clause but doesn't support replace! - do nothing (keep self's)
        end

        # Remove *all* occurrences of this clause type from the list to process further
        other_clauses_to_process.delete_if { |c| c.is_a?(clause_class) }
      end

      # --- Handle Merging Clauses (Where) ---
      other_wheres = other_query.clauses.select { |c| c.is_a?(Clause::Where) }
      unless other_wheres.empty?
        self_where = @clauses.find { |c| c.is_a?(Clause::Where) }
        if self_where
          other_wheres.each { |ow| self_where.merge!(ow) }
        else
          # Add the first other_where and merge the rest into it
          first_other_where = other_wheres.shift
          add_clause(first_other_where)
          other_wheres.each { |ow| first_other_where.merge!(ow) }
        end
        # Remove processed clauses
        other_clauses_to_process.delete_if { |c| c.is_a?(Clause::Where) }
      end

      # --- Handle Appending Clauses (Match, Create, Set, Remove, Delete, With, Return, Call, etc.) ---
      # Add remaining clauses from other_query
      other_clauses_to_process.each { |clause| add_clause(clause) }
    end

    # Helper to map instance variable names used in combine_clauses! to class types
    # This helper is no longer needed with the refactored combine_clauses!
    # def clause_class_for_ivar(ivar_name) ... end

    # Helper needed for `where` DSL method with hash conditions
    # Tries to guess the primary alias.
    # Like Sherlock Holmes, but with fewer clues and more yelling.
    def infer_alias
      # Find first Node alias defined in MATCH/CREATE/MERGE clauses
      @clauses.each do |clause|
        next unless clause.respond_to?(:pattern) && clause.pattern

        pattern = clause.pattern
        element = pattern.is_a?(Pattern::Path) ? pattern.elements.first : pattern
        return element.alias_name if element.is_a?(Pattern::Node) && element.alias_name
      end
      raise 'Cannot infer alias for WHERE hash conditions. Define a node alias in MATCH/CREATE first.'
    end

    def freeze!
      @parameters.freeze
      @clauses.each(&:freeze)
      freeze
    end
  end
end
