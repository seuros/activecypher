# frozen_string_literal: true

# Require necessary clause and pattern types

# Require all clause types for DSL methods

require 'set' # For alias conflict detection

module Cyrel
  # Error raised when merging queries with conflicting alias definitions.
  class AliasConflictError < StandardError
    def initialize(alias_name, query1_details, query2_details)
      super("Alias conflict for ':#{alias_name}'. Query 1 defines it as #{query1_details}, Query 2 defines it as #{query2_details}.")
    end
  end

  # Represents a Cypher query being built.
  # Manages clauses, parameters, and final query generation.
  class Query
    attr_reader :parameters, :clauses # Expose clauses for merge logic

    def initialize
      @parameters = {}
      @param_counter = 0
      @clauses = [] # Holds instances of Clause::Base subclasses
    end

    # Registers a value as a parameter and returns its generated key.
    # @param value [Object] The value to parameterize.
    # @return [Symbol] The parameter key (e.g., :p1, :p2).
    def register_parameter(value)
      # Check if this value already exists (Reinstating reuse logic)
      existing_key = @parameters.key(value)
      if existing_key
        # Removed puts
        return existing_key
      end

      # If not found, create a new parameter
      @param_counter += 1
      param_key = :"p#{@param_counter}"
      @parameters[param_key] = value
      # Removed puts
      param_key
    end

    # Adds a clause object to the query.
    # @param clause [Cyrel::Clause::Base] The clause instance to add.
    def add_clause(clause)
      @clauses << clause
      self # Allow chaining
    end

    # Generates the final Cypher query string and parameters hash.
    # @return [Array(String, Hash)] The Cypher string and parameters.
    def to_cypher
      # Ensure clauses are ordered correctly (e.g., MATCH before WHERE, WHERE before RETURN)
      # Basic ordering for now, might need refinement.
      ordered_clauses = @clauses.sort_by { |c| clause_order(c) }
      cypher_parts = ordered_clauses.map { |clause| clause.render(self) }
      cypher_string = cypher_parts.compact.join("\n") # Use newline for better readability
      # Removed puts
      [cypher_string, @parameters]
    end

    # Merges another query into this one.
    # @param other_query [Cyrel::Query] The query to merge in.
    # @return [self]
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
    def match(pattern, path_variable: nil)
      # TODO: Add implicit pattern construction from Hash/Array if desired.
      add_clause(Clause::Match.new(pattern, optional: false, path_variable: path_variable))
    end

    # Adds an OPTIONAL MATCH clause.
    # @param pattern [Cyrel::Pattern::Path, Node, Relationship, Hash, Array] Pattern definition.
    # @param path_variable [Symbol, String, nil] Optional variable for the path.
    # @return [self]
    def optional_match(pattern, path_variable: nil)
      add_clause(Clause::Match.new(pattern, optional: true, path_variable: path_variable))
    end

    # Adds or merges into a WHERE clause.
    # @param conditions [Array<Cyrel::Expression::Base, Object>, Hash] Conditions.
    #   - Expressions: Cyrel.prop(:n, :age) > 18
    #   - Hash: { name: "Alice", status: "Active" } (implicitly creates equality comparisons)
    # @return [self]
    def where(*conditions)
      processed_conditions = conditions.flat_map do |cond|
        if cond.is_a?(Hash)
          # Needs alias context
          cond.map do |key, value|
            Expression::Comparison.new(Expression::PropertyAccess.new(@current_alias || infer_alias, key), :"=", value)
          end
        else
          cond # Assume it's already an Expression or coercible
        end
      end

      existing_where = @clauses.find { |c| c.is_a?(Clause::Where) }
      if existing_where
        existing_where.merge!(Clause::Where.new(*processed_conditions))
      else
        add_clause(Clause::Where.new(*processed_conditions))
      end
      self
    end

    # Adds a CREATE clause.
    # @param pattern [Cyrel::Pattern::Path, Node, Relationship, Hash, Array] Pattern definition.
    # @return [self]
    def create(pattern)
      # TODO: Add implicit pattern construction
      add_clause(Clause::Create.new(pattern))
    end

    # Adds a MERGE clause.
    # @param pattern [Cyrel::Pattern::Path, Node, Relationship, Hash, Array] Pattern definition.
    # @return [self]
    def merge(pattern)
      # TODO: Add implicit pattern construction
      # TODO: Add ON CREATE SET / ON MATCH SET options
      add_clause(Clause::Merge.new(pattern))
    end

    # Adds a SET clause.
    # @param assignments [Hash, Array] See Clause::Set#initialize.
    # @return [self]
    def set(assignments)
      # TODO: Consider merging SET clauses intelligently if needed.
      add_clause(Clause::Set.new(assignments))
    end

    # Adds a REMOVE clause.
    # @param items [Array<Cyrel::Expression::PropertyAccess, Array>] See Clause::Remove#initialize.
    # @return [self]
    def remove(*items)
      # TODO: Consider merging REMOVE clauses.
      add_clause(Clause::Remove.new(items)) # Pass array directly
    end

    # Adds a DELETE clause. Use `detach_delete` for DETACH DELETE.
    # @param variables [Array<Symbol, String>] Variables to delete.
    # @return [self]
    # Underscore to avoid keyword clash
    def delete_(*variables)
      add_clause(Clause::Delete.new(*variables, detach: false))
    end

    # Adds a DETACH DELETE clause.
    # @param variables [Array<Symbol, String>] Variables to delete.
    # @return [self]
    def detach_delete(*variables)
      add_clause(Clause::Delete.new(*variables, detach: true))
    end

    # Adds a WITH clause.
    # @param items [Array] Items to project. See Clause::With#initialize.
    # @param distinct [Boolean] Use DISTINCT?
    # @param where [Cyrel::Clause::Where, Hash, Array] Optional WHERE condition(s) after WITH.
    # @return [self]
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
    def return_(*items, distinct: false)
      # TODO: Consider merging RETURN clauses?
      add_clause(Clause::Return.new(*items, distinct: distinct))
    end

    # Adds or replaces the ORDER BY clause.
    # @param order_items [Array<Array>, Hash] Ordering specifications.
    #   - Array: [[expr, :asc], [expr, :desc], ...]
    #   - Hash: { expr => :asc, expr => :desc, ... }
    # @return [self]
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

    # Checks for alias conflicts between this query and another.
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
    # Tries to infer the primary alias from MATCH/CREATE clauses
    def infer_alias
      # Find first Node alias defined in MATCH/CREATE/MERGE clauses
      @clauses.each do |clause|
        next unless clause.respond_to?(:pattern) && clause.pattern

        pattern = clause.pattern
        element = pattern.is_a?(Pattern::Path) ? pattern.elements.first : pattern
        return element.alias_name if element.is_a?(Pattern::Node) && element.alias_name
      end
      raise 'Cannot infer alias for WHERE hash conditions. Define a node alias in MATCH/CREATE first.'
      # Or maybe track @current_alias explicitly?
    end
  end
end
