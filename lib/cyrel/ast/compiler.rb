# frozen_string_literal: true

module Cyrel
  module AST
    # Compiles AST nodes into Cypher queries with optional thread-safety
    # It's like Google Translate, but for graph databases and with more reliable results
    class Compiler
      attr_reader :output, :parameters

      def initialize
        @output = StringIO.new
        if defined?(Concurrent)
          @parameters = Concurrent::Hash.new
          @param_counter = Concurrent::AtomicFixnum.new(0)
        else
          @parameters = {}
          @param_counter = 0
        end
        @first_clause = true
      end

      # Compile an AST node or array of nodes
      # Returns [cypher_string, parameters_hash]
      def compile(node_or_nodes)
        nodes = Array(node_or_nodes)

        nodes.each do |node|
          add_clause_separator unless @first_clause
          node.accept(self)
          @first_clause = false
        end

        [@output.string, @parameters]
      end

      # Visit a LIMIT node
      # Because sometimes less is more, except in this comment
      def visit_limit_node(node)
        @output << 'LIMIT '
        render_expression(node.expression)
      end

      # Visit a SKIP node
      # For when you want to jump ahead in your results
      def visit_skip_node(node)
        @output << 'SKIP '
        render_expression(node.amount)
      end

      # Visit an ORDER BY node
      # Because even chaos needs some structure sometimes
      def visit_order_by_node(node)
        @output << 'ORDER BY '
        @in_order_by = true

        node.items.each_with_index do |(expr, direction), index|
          @output << ', ' if index.positive?
          render_expression(expr)
          @output << " #{direction.to_s.upcase}" if direction && direction != :asc
        end

        @in_order_by = false
      end

      # Visit a WHERE node
      # Because sometimes you need to be selective about your relationships
      def visit_where_node(node)
        return if node.conditions.empty?

        @output << 'WHERE '

        if node.conditions.length == 1
          render_expression(node.conditions.first)
        else
          # Combine multiple conditions with AND
          node.conditions.each_with_index do |condition, index|
            @output << ' AND ' if index.positive?
            render_expression(condition)
          end
        end
      end

      # Visit a RETURN node
      # Where your data comes home to roost
      def visit_return_node(node)
        @output << 'RETURN '
        @output << 'DISTINCT ' if node.distinct

        node.items.each_with_index do |item, index|
          @output << ', ' if index.positive?
          render_expression(item)
        end
      end

      # Visit a SET node
      # Where change happens, one property at a time
      def visit_set_node(node)
        return if node.assignments.empty?

        @output << 'SET '

        node.assignments.each_with_index do |assignment, index|
          @output << ', ' if index.positive?
          render_assignment(assignment)
        end
      end

      # Visit a WITH node
      # Because sometimes you need to pass data along for the next part of your journey
      def visit_with_node(node)
        @output << 'WITH '
        @output << 'DISTINCT ' if node.distinct

        node.items.each_with_index do |item, index|
          @output << ', ' if index.positive?
          render_expression(item)
        end

        # Add WHERE clause if present
        return unless node.where_conditions && !node.where_conditions.empty?

        @output << "\nWHERE "

        if node.where_conditions.length == 1
          render_expression(node.where_conditions.first)
        else
          # Combine multiple conditions with AND
          node.where_conditions.each_with_index do |condition, index|
            @output << ' AND ' if index.positive?
            render_expression(condition)
          end
        end
      end

      # Visit an UNWIND node
      # Unpacking arrays like unwrapping presents
      def visit_unwind_node(node)
        @output << 'UNWIND '

        # Render the expression to unwind
        if node.expression.is_a?(Array)
          # Array literal
          @output << format_array_literal(node.expression)
        elsif node.expression.is_a?(Symbol)
          # Parameter reference
          param_key = register_parameter(node.expression)
          @output << "$#{param_key}"
        else
          # Other expressions
          render_expression(node.expression)
        end

        @output << " AS #{node.alias_name}"
      end

      # Visit a MATCH clause node
      # Finding nodes in the graph, one pattern at a time
      def visit_match_node(node)
        @output << (node.optional ? 'OPTIONAL MATCH ' : 'MATCH ')

        # Handle path variable assignment if present
        @output << "#{node.path_variable} = " if node.path_variable

        # Render the pattern
        render_pattern(node.pattern)
      end

      # Visit a CREATE clause node
      # Making nodes and relationships appear out of thin air
      def visit_create_node(node)
        @output << 'CREATE '
        render_pattern(node.pattern)
      end

      # Visit a MERGE clause node
      # Finding or creating, because commitment issues
      def visit_merge_node(node)
        @output << 'MERGE '
        render_pattern(node.pattern)

        # Handle ON CREATE SET
        if node.on_create
          @output << "\nON CREATE SET "
          render_merge_assignments(node.on_create)
        end

        # Handle ON MATCH SET
        return unless node.on_match

        @output << "\nON MATCH SET "
        render_merge_assignments(node.on_match)
      end

      # Visit a DELETE clause node
      # Making nodes disappear, potentially with their relationships
      def visit_delete_node(node)
        @output << 'DETACH ' if node.detach
        @output << 'DELETE '

        node.variables.each_with_index do |var, i|
          @output << ', ' if i.positive?
          @output << var.to_s
        end
      end

      # Visit a REMOVE clause node
      # Tidying up properties and labels
      def visit_remove_node(node)
        @output << 'REMOVE '

        node.items.each_with_index do |item, i|
          @output << ', ' if i.positive?

          case item
          when Expression::PropertyAccess
            # Remove property
            render_expression(item)
          when Array
            # Remove label [variable, label]
            variable, label = item
            @output << "#{variable}:#{label}"
          else
            raise "Unknown REMOVE item type: #{item.class}"
          end
        end
      end

      # Visit a CALL clause node (procedure call)
      # Invoking the stored procedures of the graph database
      def visit_call_node(node)
        @output << "CALL #{node.procedure_name}"

        if node.arguments.any?
          @output << '('
          node.arguments.each_with_index do |arg, i|
            @output << ', ' if i.positive?
            render_expression(Expression.coerce(arg))
          end
          @output << ')'
        end

        return unless node.yield_items

        @output << ' YIELD '
        if node.yield_items.is_a?(Hash)
          # YIELD items with aliases
          node.yield_items.each_with_index do |(item, alias_name), i|
            @output << ', ' if i.positive?
            @output << item.to_s
            @output << " AS #{alias_name}" if alias_name && alias_name != item
          end
        else
          # Simple yield list
          Array(node.yield_items).each_with_index do |item, i|
            @output << ', ' if i.positive?
            @output << item.to_s
          end
        end
      end

      # Visit a CALL subquery node
      # Queries all the way down
      def visit_call_subquery_node(node)
        @output << "CALL {\n"

        # Render subquery clauses directly without going through the cache
        # to avoid recursive locking issues
        subquery = node.subquery
        subquery_clauses = subquery.clauses.sort_by { |clause| subquery.send(:clause_order, clause) }

        subquery_clauses.each_with_index do |clause, index|
          @output << "\n" if index.positive? # Add newline between clauses

          if clause.is_a?(AST::ClauseAdapter)
            # For AST-based clauses, compile directly without cache
            # Create a proxy object that forwards parameter registration to this compiler
            parameter_proxy = Object.new
            parent_compiler = self
            parameter_proxy.define_singleton_method(:register_parameter) do |value|
              parent_compiler.send(:register_parameter, value)
            end

            subquery_compiler = QueryIntegratedCompiler.new(parameter_proxy)
            clause_cypher, = subquery_compiler.compile(clause.ast_node)
            @output << clause_cypher.split("\n").map { |line| "  #{line}" }.join("\n")
          else
            # For legacy clauses, render normally
            clause_output = clause.render(subquery)
            @output << clause_output.split("\n").map { |line| "  #{line}" }.join("\n") unless clause_output.blank?

            # Merge subquery parameters
            subquery.parameters.each_value do |value|
              register_parameter(value)
            end
          end
        end

        @output << "\n}"
      end

      # Visit a UNION node
      # Combining queries like a Cypher mixologist
      def visit_union_node(node)
        # UNION is special - it combines complete queries
        # We need to render each query's clauses directly to avoid recursive locking
        node.queries.each_with_index do |query, index|
          if index.positive?
            @output << "\n"
            @output << 'UNION'
            @output << ' ALL' if node.all
            @output << "\n"
          end

          # Render query clauses directly without going through cache
          query_clauses = query.clauses.sort_by { |clause| query.send(:clause_order, clause) }

          query_clauses.each_with_index do |clause, clause_index|
            @output << "\n" if clause_index.positive?

            if clause.is_a?(AST::ClauseAdapter)
              # For AST-based clauses, compile directly without cache
              # Create a proxy object that forwards parameter registration to this compiler
              parameter_proxy = Object.new
              parent_compiler = self
              parameter_proxy.define_singleton_method(:register_parameter) do |value|
                parent_compiler.send(:register_parameter, value)
              end

              clause_compiler = QueryIntegratedCompiler.new(parameter_proxy)
              clause_cypher, = clause_compiler.compile(clause.ast_node)
              @output << clause_cypher
            else
              # For legacy clauses, render normally
              clause_output = clause.render(query)
              @output << clause_output unless clause_output.blank?

              # Merge query parameters
              query.parameters.each_value do |value|
                register_parameter(value)
              end
            end
          end
        end
      end

      # Visit a FOREACH node
      # Iterating through lists like a database therapist
      def visit_foreach_node(node)
        @output << "FOREACH (#{node.variable} IN "

        # Handle the expression - could be an array literal or an expression
        if node.expression.is_a?(Array)
          # Array literal - convert to parameter
          param_key = register_parameter(node.expression)
          @output << "$#{param_key}"
        elsif node.expression.is_a?(Symbol)
          # Symbol reference to parameter
          param_key = register_parameter(node.expression)
          @output << "$#{param_key}"
        else
          # Other expressions
          render_expression(node.expression)
        end

        @output << ' | '

        # Render update clauses without duplication
        node.update_clauses.each_with_index do |clause, index|
          @output << ' ' if index.positive?

          raise "Unexpected clause type in FOREACH: #{clause.class}" unless clause.is_a?(AST::ClauseAdapter)

          # For AST-based clauses, compile just the inner content
          # Create a proxy object that forwards parameter registration to this compiler
          parameter_proxy = Object.new
          parent_compiler = self
          parameter_proxy.define_singleton_method(:register_parameter) do |value|
            parent_compiler.send(:register_parameter, value)
          end

          inner_compiler = QueryIntegratedCompiler.new(parameter_proxy)
          clause_cypher, = inner_compiler.compile([clause.ast_node])
          @output << clause_cypher

          # For other clause types, render directly
        end

        @output << ')'
      end

      # Visit a LOAD CSV node
      # Reading CSV files like it's 1999
      def visit_load_csv_node(node)
        @output << 'LOAD CSV'
        @output << ' WITH HEADERS' if node.with_headers
        @output << ' FROM '

        # URL can be a string or expression
        if node.url.is_a?(String)
          param_key = register_parameter(node.url)
          @output << "$#{param_key}"
        else
          render_expression(node.url)
        end

        @output << " AS #{node.variable}"

        return unless node.fieldterminator

        @output << ' FIELDTERMINATOR '
        param_key = register_parameter(node.fieldterminator)
        @output << "$#{param_key}"
      end

      # Visit a literal value node
      # The most honest node in the entire tree
      def visit_literal_node(node)
        if node.value.is_a?(Symbol)
          # Symbols are parameter references, not values to be parameterized
          @output << "$#{node.value}"
        else
          # All other literals become parameters for consistency with existing behavior
          param_key = register_parameter(node.value)
          @output << "$#{param_key}"
        end
      end

      private

      def add_clause_separator
        @output << "\n"
      end

      # Render a pattern (node, relationship, or path)
      def render_pattern(pattern)
        # Patterns have their own render methods
        raise "Don't know how to render pattern: #{pattern.inspect}" unless pattern.respond_to?(:render)

        @output << pattern.render(@query || self)
      end

      # Render a SET assignment based on its type
      def render_assignment(assignment)
        type, *args = assignment

        case type
        when :property
          # SET n.prop = value
          prop_access, value = args
          render_expression(prop_access)
          @output << ' = '
          render_expression(value)
        when :variable_properties
          # SET n = {props} or SET n += {props}
          variable, value, operator = args
          @output << variable.to_s
          @output << (operator == :merge ? ' += ' : ' = ')
          render_expression(value)
        when :label
          # SET n:Label
          variable, label = args
          @output << "#{variable}:#{label}"
        else
          raise "Unknown assignment type: #{type}"
        end
      end

      # Render merge assignments (ON CREATE/MATCH SET)
      def render_merge_assignments(assignments)
        case assignments
        when Array
          assignments.each_with_index do |item, i|
            @output << ', ' if i.positive?
            render_set_item(item)
          end
        when Hash
          assignments.each_with_index do |(key, value), i|
            @output << ', ' if i.positive?
            render_expression(key)
            @output << ' = '
            render_expression(Expression.coerce(value))
          end
        else
          raise "Unknown assignments type: #{assignments.class}"
        end
      end

      # Render a single SET item (for MERGE ON CREATE/MATCH SET)
      def render_set_item(item)
        case item
        when Array
          # It's a property assignment like [:n, :name, "value"]
          variable, property, value = item
          @output << "#{variable}.#{property} = "
          render_expression(Expression.coerce(value))
        else
          raise "Unknown SET item type: #{item.class}"
        end
      end

      # Render an expression (could be a literal, parameter, property access, etc.)
      def render_expression(expr)
        case expr
        in Node
          # It's already an AST node
          expr.accept(self)
        in Clause::Return::RawIdentifier
          # Raw identifiers (variable names) are rendered as-is
          @output << expr.identifier
        in Symbol
          # Symbols in ORDER BY context are identifiers, not parameters
          # In other contexts, they should be parameterized
          if @in_order_by
            @output << expr.to_s
          else
            # Parameterize the symbol
            param_key = register_parameter(expr)
            @output << "$#{param_key}"
          end
        in Numeric | true | false | nil
          # Wrap in literal node and visit
          LiteralNode.new(expr).accept(self)
        in String
          # Strings should be parameterized
          LiteralNode.new(expr).accept(self)
        else
          # Try common methods
          if expr.respond_to?(:render)
            # Has a render method (like PropertyAccess, FunctionCall, etc.)
            @output << expr.render(@query || self)
          elsif expr.respond_to?(:to_ast)
            # Has a to_ast method
            expr.to_ast.accept(self)
          else
            raise "Don't know how to render expression: #{expr.inspect}"
          end
        end
      end

      # Register a parameter and return its key (thread-safe if Concurrent is available)
      # Because $p1, $p2, $p3 is the naming convention we deserve
      def register_parameter(value)
        existing_key = @parameters.key(value)
        return existing_key if existing_key

        if defined?(Concurrent) && @parameters.is_a?(Concurrent::Hash)
          # Thread-safe parameter registration

          counter = @param_counter.increment
          key = :"p#{counter}"
        else
          # Non-concurrent version

          @param_counter += 1
          key = :"p#{@param_counter}"
        end
        @parameters[key] = value
        key
      end

      # Format an array literal for Cypher output
      def format_array_literal(array)
        elements = array.map do |element|
          case element
          when String
            "'#{element}'"
          when Symbol
            "'#{element}'"
          when Array
            format_array_literal(element)
          else
            element.to_s
          end
        end
        "[#{elements.join(', ')}]"
      end
    end
  end
end
