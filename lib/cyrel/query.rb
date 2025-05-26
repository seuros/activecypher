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
      @loop_variables = Set.new # Track loop variables for FOREACH context
    end

    # Registers a value and returns a parameter key.
    # Think of it as variable adoption but with less paperwork and more risk.
    # @param value [Object] The value to parameterize.
    # @return [Symbol] The parameter key (e.g., :p1, :p2).
    # Because nothing says "safe query" like a parade of anonymous parameters.
    def register_parameter(value)
      # Don't parameterize loop variables in FOREACH context
      if value.is_a?(Symbol) && @loop_variables.include?(value)
        return value # Return the symbol itself, not a parameter key
      end

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
                        .sort_by { |clause| clause_order(clause) }
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
      # Use AST-based implementation
      match_node = AST::MatchNode.new(pattern, optional: false, path_variable: path_variable)
      ast_clause = AST::ClauseAdapter.new(match_node)
      add_clause(ast_clause)
    end

    # Adds an OPTIONAL MATCH clause.
    # @param pattern [Cyrel::Pattern::Path, Node, Relationship, Hash, Array] Pattern definition.
    # @param path_variable [Symbol, String, nil] Optional variable for the path.
    # @return [self]
    # For when you want to be non-committal, even in your queries.
    def optional_match(pattern, path_variable: nil)
      # Use AST-based implementation
      match_node = AST::MatchNode.new(pattern, optional: true, path_variable: path_variable)
      ast_clause = AST::ClauseAdapter.new(match_node)
      add_clause(ast_clause)
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

      # Use AST-based implementation
      where_node = AST::WhereNode.new(processed_conditions)
      ast_clause = AST::ClauseAdapter.new(where_node)

      # ------------------------------------------------------------------
      # 2. Merge with an existing WHERE (if any)
      # ------------------------------------------------------------------
      existing_where_index = @clauses.find_index { |c| c.is_a?(Clause::Where) || (c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(AST::WhereNode)) }

      if existing_where_index
        existing_clause = @clauses[existing_where_index]
        if existing_clause.is_a?(AST::ClauseAdapter) && existing_clause.ast_node.is_a?(AST::WhereNode)
          # Merge conditions by creating a new WHERE node with combined conditions
          combined_conditions = existing_clause.ast_node.conditions + processed_conditions
          merged_where_node = AST::WhereNode.new(combined_conditions)
          @clauses[existing_where_index] = AST::ClauseAdapter.new(merged_where_node)
        else
          # Replace old-style WHERE with AST WHERE
          @clauses[existing_where_index] = ast_clause
        end
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
        @clauses.insert(insertion_index, ast_clause)
      else
        @clauses << ast_clause
      end

      self
    end

    # Adds a CREATE clause.
    # @param pattern [Cyrel::Pattern::Path, Node, Relationship, Hash, Array] Pattern definition.
    # @return [self]
    # Because sometimes you want to make things, not just break them.
    def create(pattern)
      # Use AST-based implementation
      create_node = AST::CreateNode.new(pattern)
      ast_clause = AST::ClauseAdapter.new(create_node)
      add_clause(ast_clause)
    end

    # Adds a MERGE clause.
    # @param pattern [Cyrel::Pattern::Path, Node, Relationship, Hash, Array] Pattern definition.
    # @param on_create [Array, Hash] Optional ON CREATE SET assignments
    # @param on_match [Array, Hash] Optional ON MATCH SET assignments
    # @return [self]
    # For when you want to find-or-create, but with more existential angst.
    def merge(pattern, on_create: nil, on_match: nil)
      # Use AST-based implementation
      merge_node = AST::MergeNode.new(pattern, on_create: on_create, on_match: on_match)
      ast_clause = AST::ClauseAdapter.new(merge_node)
      add_clause(ast_clause)
    end

    # Adds a SET clause.
    # @param assignments [Hash, Array] See Clause::Set#initialize.
    # @return [self]
    # Because sometimes you just want to change everything and pretend it was always that way.
    def set(assignments)
      # Process assignments similar to existing Set clause
      processed_assignments = case assignments
                              when Hash
                                assignments.flat_map do |key, value|
                                  case key
                                  when Expression::PropertyAccess
                                    # SET n.prop = value
                                    [[:property, key, Expression.coerce(value)]]
                                  when Symbol, String
                                    # SET n = properties
                                    raise ArgumentError, 'Value for variable assignment must be a Hash' unless value.is_a?(Hash)

                                    [[:variable_properties, key.to_sym, Expression.coerce(value), :assign]]
                                  when Cyrel::Plus
                                    # SET n += properties
                                    raise ArgumentError, 'Value for variable assignment must be a Hash' unless value.is_a?(Hash)

                                    [[:variable_properties, key.variable.to_sym, Expression.coerce(value), :merge]]
                                  else
                                    raise ArgumentError, "Invalid key type in SET assignments: #{key.class}"
                                  end
                                end
                              when Array
                                assignments.map do |item|
                                  unless item.is_a?(Array) && item.length == 2
                                    raise ArgumentError, "Invalid label assignment format. Expected [[:variable, 'Label'], ...], got #{item.inspect}"
                                  end

                                  # SET n:Label
                                  [:label, item[0].to_sym, item[1]]
                                end
                              else
                                raise ArgumentError, "Invalid assignments type: #{assignments.class}"
                              end

      set_node = AST::SetNode.new(processed_assignments)
      ast_clause = AST::ClauseAdapter.new(set_node)

      # Check for existing SET clause to merge with
      existing_set_index = @clauses.find_index { |c| c.is_a?(Clause::Set) || (c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(AST::SetNode)) }

      if existing_set_index
        existing_clause = @clauses[existing_set_index]
        if existing_clause.is_a?(AST::ClauseAdapter) && existing_clause.ast_node.is_a?(AST::SetNode)
          # Merge with existing AST SET node by creating a new one with combined assignments
          combined_assignments = existing_clause.ast_node.assignments + processed_assignments
          merged_set_node = AST::SetNode.new(combined_assignments)
        else
          # Replace old clause-based SET with merged AST version
          combined_assignments = existing_clause.assignments + set_node.assignments
          merged_set_node = AST::SetNode.new({})
          merged_set_node.instance_variable_set(:@assignments, combined_assignments)
        end
        @clauses[existing_set_index] = AST::ClauseAdapter.new(merged_set_node)
      else
        add_clause(ast_clause)
      end

      self
    end

    # Adds a REMOVE clause.
    # @param items [Array<Cyrel::Expression::PropertyAccess, Array>] See Clause::Remove#initialize.
    # @return [self]
    # For when you want to Marie Kondo your graph.
    def remove(*items)
      # Use AST-based implementation
      remove_node = AST::RemoveNode.new(items)
      ast_clause = AST::ClauseAdapter.new(remove_node)
      add_clause(ast_clause)
    end

    # Adds a DELETE clause. Use `detach_delete` for DETACH DELETE.
    # @param variables [Array<Symbol, String>] Variables to delete.
    # @return [self]
    # Underscore to avoid keyword clash
    # Because sometimes you just want to watch the world burn, one node at a time.
    def delete_(*variables)
      # Use AST-based implementation
      delete_node = AST::DeleteNode.new(variables, detach: false)
      ast_clause = AST::ClauseAdapter.new(delete_node)
      add_clause(ast_clause)
    end

    # Adds a DETACH DELETE clause.
    # @param variables [Array<Symbol, String>] Variables to delete.
    # @return [self]
    # For when you want to delete with extreme prejudice.
    def detach_delete(*variables)
      # Use AST-based implementation
      delete_node = AST::DeleteNode.new(variables, detach: true)
      ast_clause = AST::ClauseAdapter.new(delete_node)
      add_clause(ast_clause)
    end

    # Adds a WITH clause.
    # @param items [Array] Items to project. See Clause::With#initialize.
    # @param distinct [Boolean] Use DISTINCT?
    # @param where [Cyrel::Clause::Where, Hash, Array] Optional WHERE condition(s) after WITH.
    # @return [self]
    # Because sometimes you want to pass things along, and sometimes you just want to pass the buck.
    def with(*items, distinct: false, where: nil)
      # Process items similar to existing Return clause
      processed_items = items.flatten.map do |item|
        case item
        when Expression::Base
          item
        when Symbol
          # Create a RawIdentifier for variable names
          Clause::Return::RawIdentifier.new(item.to_s)
        when String
          # Check if string looks like property access (e.g. "person.name")
          # If so, treat as raw identifier, otherwise parameterize
          if item.match?(/\A\w+\.\w+\z/)
            Clause::Return::RawIdentifier.new(item)
          else
            # String literals should be coerced to expressions (parameterized)
            Expression.coerce(item)
          end
        else
          Expression.coerce(item)
        end
      end

      # Process WHERE conditions if provided
      where_conditions = case where
                         when nil then []
                         when Hash
                           # Convert hash to equality comparisons
                           where.map do |key, value|
                             Expression::Comparison.new(
                               Expression::PropertyAccess.new(@current_alias || infer_alias, key),
                               :'=',
                               value
                             )
                           end
                         when Array then where
                         else [where] # Single condition
                         end

      # Use AST-based implementation
      with_node = AST::WithNode.new(processed_items, distinct: distinct, where_conditions: where_conditions)
      ast_clause = AST::ClauseAdapter.new(with_node)

      # Find and replace existing with or add new one
      existing_with_index = @clauses.find_index { |c| c.is_a?(Clause::With) || (c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(AST::WithNode)) }

      if existing_with_index
        @clauses[existing_with_index] = ast_clause
      else
        add_clause(ast_clause)
      end

      self
    end

    # Adds a RETURN clause.
    # @param items [Array] Items to return. See Clause::Return#initialize.
    # @param distinct [Boolean] Use DISTINCT?
    # @return [self]
    #
    # Note: Method is named `return_` with an underscore suffix because `return`
    # is a reserved keyword in Ruby. We're not crazy - we just want to provide
    # a clean DSL while respecting Ruby's language constraints.
    def return_(*items, distinct: false)
      # Process items similar to existing Return clause
      processed_items = items.flatten.map do |item|
        case item
        when Expression::Base
          item
        when Symbol
          # Create a RawIdentifier for variable names
          Clause::Return::RawIdentifier.new(item.to_s)
        when String
          # Check if string looks like property access (e.g. "person.name")
          # If so, treat as raw identifier, otherwise parameterize
          if item.match?(/\A\w+\.\w+\z/)
            Clause::Return::RawIdentifier.new(item)
          else
            # String literals should be coerced to expressions (parameterized)
            Expression.coerce(item)
          end
        else
          Expression.coerce(item)
        end
      end

      # Use AST-based implementation
      return_node = AST::ReturnNode.new(processed_items, distinct: distinct)
      ast_clause = AST::ClauseAdapter.new(return_node)

      # Find and replace existing return or add new one
      existing_return_index = @clauses.find_index { |c| c.is_a?(Clause::Return) || (c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(AST::ReturnNode)) }

      if existing_return_index
        @clauses[existing_return_index] = ast_clause
      else
        add_clause(ast_clause)
      end
      self
    end

    # Adds or replaces the ORDER BY clause.
    # @param order_items [Array<Array>, Hash] Ordering specifications.
    #   - Array: [[expr, :asc], [expr, :desc], ...]
    #   - Hash: { expr => :asc, expr => :desc, ... }
    # @return [self]
    # Because sometimes you want order, and sometimes you just want chaos.
    def order_by(*order_items)
      items_array = order_items.first.is_a?(Hash) ? order_items.first.to_a : order_items

      # Use AST-based implementation
      order_by_node = AST::OrderByNode.new(items_array)
      ast_clause = AST::ClauseAdapter.new(order_by_node)

      # Find and replace existing order by or add new one
      existing_order_index = @clauses.find_index { |c| c.is_a?(Clause::OrderBy) || (c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(AST::OrderByNode)) }

      if existing_order_index
        @clauses[existing_order_index] = ast_clause
      else
        add_clause(ast_clause)
      end
      self
    end

    # Adds or replaces the SKIP clause.
    # @param amount [Integer, Expression] Number of results to skip.
    # @return [self]
    # For when you want to ignore the first N results, just like your unread emails.
    def skip(amount)
      # Use AST-based implementation
      skip_node = AST::SkipNode.new(amount)
      ast_clause = AST::ClauseAdapter.new(skip_node)

      # Find and replace existing skip or add new one
      existing_skip_index = @clauses.find_index { |c| c.is_a?(Clause::Skip) || (c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(AST::SkipNode)) }

      if existing_skip_index
        @clauses[existing_skip_index] = ast_clause
      else
        add_clause(ast_clause)
      end
      self
    end

    # Adds or replaces the LIMIT clause.
    # @param amount [Integer, Expression] Maximum number of results.
    # @return [self]
    # Because sometimes you want boundaries, even in your queries.
    def limit(amount)
      # Use AST-based implementation
      limit_node = AST::LimitNode.new(amount)
      ast_clause = AST::ClauseAdapter.new(limit_node)

      # Find and replace existing limit or add new one
      existing_limit_index = @clauses.find_index { |c| c.is_a?(Clause::Limit) || (c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(AST::LimitNode)) }

      if existing_limit_index
        @clauses[existing_limit_index] = ast_clause
      else
        add_clause(ast_clause)
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
      # Use AST-based implementation for simple CALL
      # Note: WHERE and RETURN after YIELD are not yet supported in AST version
      if where || return_items
        # Fall back to clause-based for complex cases
        add_clause(Clause::Call.new(procedure_name,
                                    arguments: arguments,
                                    yield_items: yield_items,
                                    where: where,
                                    return_items: return_items))
      else
        call_node = AST::CallNode.new(procedure_name, arguments: arguments, yield_items: yield_items)
        ast_clause = AST::ClauseAdapter.new(call_node)
        add_clause(ast_clause)
      end
      self
    end

    # Adds a CALL { subquery } clause.
    # @yield [Cyrel::Query] Yields a new query object for building the subquery.
    # @return [self]
    # Because why write one query when you can write two and glue them together?
    def call_subquery
      subquery = Cyrel::Query.new
      yield subquery
      # Use AST-based implementation
      call_subquery_node = AST::CallSubqueryNode.new(subquery)
      ast_clause = AST::ClauseAdapter.new(call_subquery_node)
      add_clause(ast_clause)
    end

    # Adds an UNWIND clause.
    # @param expression [Array, Symbol, Object] The list expression to unwind
    # @param variable [Symbol, String] The variable name to bind each element to
    # @return [self]
    # For when you want to turn one row with a list into many rows with values,
    # like unpacking a suitcase but for data
    # Example: query.unwind([1,2,3], :x).return_(:x)
    #          query.unwind(:names, :name).create(...)
    def unwind(expression, variable)
      # Create an AST UnwindNode wrapped in a ClauseAdapter
      ast_node = AST::UnwindNode.new(expression, variable)
      add_clause(AST::ClauseAdapter.new(ast_node))
    end

    # No longer private, needed by merge!
    # Combines this query with another using UNION
    # @param other_query [Cyrel::Query] The query to union with
    # @return [Cyrel::Query] A new query representing the union
    def union(other_query)
      self.class.union_queries([self, other_query], all: false)
    end

    # Combines this query with another using UNION ALL
    # @param other_query [Cyrel::Query] The query to union with
    # @return [Cyrel::Query] A new query representing the union
    def union_all(other_query)
      self.class.union_queries([self, other_query], all: true)
    end

    # Combines multiple queries using UNION or UNION ALL
    # @param queries [Array<Cyrel::Query>] The queries to combine
    # @param all [Boolean] Whether to use UNION ALL (true) or UNION (false)
    # @return [Cyrel::Query] A new query representing the union
    def self.union_queries(queries, all: false)
      raise ArgumentError, 'UNION requires at least 2 queries' if queries.size < 2

      # Create a new query that represents the union
      union_query = new
      union_node = AST::UnionNode.new(queries, all: all)
      union_query.add_clause(AST::ClauseAdapter.new(union_node))
      union_query
    end

    # Adds a FOREACH clause for iterating over a list with update operations
    # @param variable [Symbol] The iteration variable
    # @param expression [Expression, Array] The list to iterate over
    # @param update_clauses [Array<Clause>] The update clauses to execute for each element
    # @return [self]
    def foreach(variable, expression)
      # If a block is given, create a sub-query context for update clauses
      raise ArgumentError, 'FOREACH requires a block with update clauses' unless block_given?

      sub_query = self.class.new
      # Pass loop variable context to sub-query
      sub_query.instance_variable_set(:@loop_variables, @loop_variables.dup)
      sub_query.instance_variable_get(:@loop_variables).add(variable.to_sym)

      yield sub_query
      update_clauses = sub_query.clauses

      foreach_node = AST::ForeachNode.new(variable, expression, update_clauses)
      add_clause(AST::ClauseAdapter.new(foreach_node))
    end

    # Adds a LOAD CSV clause for importing CSV data
    # @param url [String] The URL or file path to load CSV from
    # @param variable [Symbol] The variable to bind each row to
    # @param with_headers [Boolean] Whether the CSV has headers
    # @param fieldterminator [String] The field delimiter (default is comma)
    # @return [self]
    def load_csv(from:, as:, with_headers: false, fieldterminator: nil)
      load_csv_node = AST::LoadCsvNode.new(from, as, with_headers: with_headers, fieldterminator: fieldterminator)
      add_clause(AST::ClauseAdapter.new(load_csv_node))
    end

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
      # All clauses should be AST-based now
      return 997 unless clause.is_a?(AST::ClauseAdapter)

      # Clause ordering values - lower numbers come first
      case clause.ast_node
      when AST::LoadCsvNode then 2
      when AST::MatchNode then 5
      when AST::CallNode, AST::CallSubqueryNode then 7
      when AST::WhereNode
        # WHERE can come after different clauses - check what came before
        # This is a simplified approach - a more sophisticated one would
        # track the actual clause relationships
        has_load_csv = @clauses.any? { |c| c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(AST::LoadCsvNode) }
        has_load_csv ? 3 : 11
      when AST::WithNode then 13
      when AST::UnwindNode then 17
      when AST::CreateNode then 23
      when AST::MergeNode then 23
      when AST::SetNode then 29
      when AST::RemoveNode then 29
      when AST::DeleteNode then 29
      when AST::ForeachNode then 31
      when AST::ReturnNode then 37
      when AST::OrderByNode then 41
      when AST::SkipNode then 43
      when AST::LimitNode then 47
      when AST::UnionNode then 53
      else 997
      end
    end

    # Extracts defined aliases and their labels from the query's clauses.
    # @return [Hash{Symbol => Set<String>}] { alias_name => Set[label1, label2] }
    # Because even your variables want to be unique snowflakes.
    def defined_aliases
      aliases = {}
      @clauses.each do |clause|
        # Look for AST clauses that define patterns (Match, Create, Merge)
        next unless clause.is_a?(AST::ClauseAdapter)

        pattern = case clause.ast_node
                  when AST::MatchNode, AST::CreateNode, AST::MergeNode
                    clause.ast_node.pattern
                  end

        next unless pattern

        elements_to_check = []
        case pattern
        when Pattern::Path
          elements_to_check.concat(pattern.elements)
        when Pattern::Node, Pattern::Relationship
          elements_to_check << pattern
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
      [AST::OrderByNode, AST::SkipNode, AST::LimitNode].each do |ast_class|
        # Helper to check if a clause matches the type we're looking for
        clause_matcher = lambda do |c|
          c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(ast_class)
        end

        # Find the last occurrence in the other query's clauses
        other_clause = other_clauses_to_process.reverse.find(&clause_matcher)
        next unless other_clause

        # Find the clause in self, if it exists
        self_clause = @clauses.find(&clause_matcher)

        if self_clause && other_clause
          # Replace the existing clause
          self_clause_index = @clauses.index(self_clause)
          @clauses[self_clause_index] = other_clause
        elsif !self_clause
          # If self doesn't have the clause, add the one from other_query
          add_clause(other_clause)
        end

        # Remove *all* occurrences of this clause type from the list to process further
        other_clauses_to_process.delete_if(&clause_matcher)
      end

      # --- Handle Merging Clauses (Where) ---
      other_wheres = other_query.clauses.select { |c| c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(AST::WhereNode) }
      unless other_wheres.empty?
        self_where = @clauses.find { |c| c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(AST::WhereNode) }
        if self_where
          # For AST WHERE nodes, we need to merge the conditions
          other_wheres.each do |ow|
            # Extract conditions from both WHERE nodes and create a new merged one
            self_conditions = self_where.ast_node.conditions
            other_conditions = ow.ast_node.conditions
            merged_where_node = AST::WhereNode.new(self_conditions + other_conditions)
            self_where_index = @clauses.index(self_where)
            @clauses[self_where_index] = AST::ClauseAdapter.new(merged_where_node)
          end
        else
          # Add the first other_where
          add_clause(other_wheres.first)
        end
        # Remove processed clauses
        other_clauses_to_process.delete_if { |c| c.is_a?(AST::ClauseAdapter) && c.ast_node.is_a?(AST::WhereNode) }
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
        next unless clause.is_a?(AST::ClauseAdapter)

        pattern = case clause.ast_node
                  when AST::MatchNode, AST::CreateNode, AST::MergeNode
                    clause.ast_node.pattern
                  end

        next unless pattern

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
