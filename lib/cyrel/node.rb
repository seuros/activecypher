# frozen_string_literal: true

module Cyrel
  # The base class for building Cypher queries.
  class Node
    # @param label [String] The label of the node.
    # @param as [Symbol, nil] An optional alias for the node.
    def initialize(label, as: nil)
      @label = label
      @alias = as || label.to_s.underscore.to_sym
      @conditions = {}
      @raw_conditions = []
      @related_node_conditions = {}
      @optional_match = false
      @return_fields = []
      @order_clauses = []
      @skip_value = nil
      @limit_value = nil
      @with_clause = nil
      @where_after_with = nil
      @remove_props = []
      @detach_delete = false
      @path_variable = nil
    end

    # Adds conditions to the query.
    # @param conditions [Hash, String] A hash of conditions or a raw condition string to add to the query.
    def where(conditions)
      if conditions.is_a?(String)
        # Process string-based conditions
        if @with_clause && !@where_after_with.nil?
          @where_after_with = "#{@where_after_with} AND #{conditions}"
        elsif @with_clause
          @where_after_with = conditions
        else
          @raw_conditions << conditions
        end
      else
        conditions = conditions.transform_keys(&:to_s)
        if @outgoing_relationship && @related_node_label
          @related_node_conditions.merge!(conditions)
        else
          @conditions.merge!(conditions)
        end
      end
      self
    end

    # Match all nodes of this type
    def all
      self
    end

    # Specifies what to return in the query.
    # Also raises an exception if you try to be too clever—because your cleverness is not welcome here.
    # @param fields [Array<Symbol, String>] The fields to return.
    def return(*fields)
      fields.each do |field|
        # Skip validation for path variables and variables from subqueries
        next if field.is_a?(String) && (field == @path_variable.to_s || (field.match(/^\w+$/) && defined_in_query?(field)))

        if field.is_a?(Symbol) || (field.is_a?(String) && !field.include?('.') && !field.include?(' as ') &&
                                  !field.include?('(') && !field.match(/\[.+\]/))
          raise StandardError, 'Ambiguous name. Please use a string with alias.'
        end
      end
      @return_fields = fields
      self
    end

    # Defines the pattern to MATCH.
    # Not to be confused with your desperate search for compatibility on dating apps.
    def match(pattern)
      @match_pattern = pattern
      self
    end

    def set(properties)
      @set_properties = properties
      self
    end

    def create(properties)
      @create_properties = properties
      self
    end

    def merge(properties)
      @merge_properties = properties
      self
    end

    def remove(*properties)
      @remove_props.concat(properties)
      self
    end

    # Schedules the node for DEATH, WITH DETACHMENT.
    # Cold, clean, and emotionally unavailable. Just like your ex.
    def detach_delete
      @detach_delete = true
      self
    end

    def order_by(field, direction = :asc)
      @order_clauses << { field: field, direction: direction }
      self
    end

    def skip(amount)
      @skip_value = amount
      self
    end

    def limit(amount)
      @limit_value = amount
      self
    end

    def with(clause)
      @with_clause = clause
      self
    end

    def as_path(path_variable)
      @path_variable = path_variable
      self
    end

    # Builds a WHERE EXISTS subquery.
    # A fancy way to say, “Does this thing even exist?”—the same question your self-esteem asks daily.
    def where_exists(&)
      subquery = self.class.new(@label, as: @alias)
      subquery.instance_eval(&)
      pattern = "(#{@alias})"

      if subquery.instance_variable_get(:@outgoing_relationship)
        rel = subquery.instance_variable_get(:@outgoing_relationship)
        rel_node_label = subquery.instance_variable_get(:@related_node_label)
        pattern += "-[:#{rel}]->(:#{rel_node_label})"
      end

      @raw_conditions << "EXISTS(#{pattern})"
      self
    end

    # Invokes a subquery block. Like a Matryoshka of complexity.
    # Because why write one query when you can write *two* for double the confusion?
    def call(&)
      if block_given?
        subquery = self.class.new(@label, as: @alias)
        subquery.instance_eval(&)
        @call_subquery = subquery
      else
        # This is for standalone call
      end
      self
    end

    # Specifies an outgoing relationship.
    # @param relationship [Symbol] The type of relationship.
    def outgoing(relationship)
      @outgoing_relationship = relationship
      self
    end

    # Specifies an optional outgoing relationship.
    # It’s not ghosting, it’s just... optional commitment.
    def optional_outgoing(relationship)
      @outgoing_relationship = relationship
      @optional_match = true
      self
    end

    # Specifies a related node.
    # @param label [String] The label of the related node.
    # @param as [Symbol, nil] An optional alias for the related node.
    def node(label, as: nil)
      @related_node_label = label
      @related_node_alias = as || label.to_s.underscore.to_sym
      self
    end

    # This method assembles the final Cypher query like Dr. Frankenstein assembling a monster:
    # a bit of this, a stitch of that, and screaming at lightning until it runs.
    # If this explodes, blame the architecture, not the architect.
    # @return [String] The Cypher query string.
    def to_cypher
      parts = []

      # CREATE or MERGE clauses
      if @create_properties
        formatted_props = format_properties(@create_properties)
        parts << "CREATE (#{@alias}:#{@label} {#{formatted_props}})"
      elsif @merge_properties
        formatted_props = format_properties(@merge_properties)
        parts << "MERGE (#{@alias}:#{@label} {#{formatted_props}})"
      else
        # Build MATCH clause
        match_clause = build_match_clause
        parts << match_clause if match_clause
      end

      # Add CALL subquery if present
      if @call_subquery
        subquery_cypher = @call_subquery.to_cypher
        # Format for subquery in CALL
        subquery_cypher = subquery_cypher.gsub(/^MATCH /, '')
        parts << "CALL { MATCH #{subquery_cypher} }"
      end

      # WITH clause
      parts << "WITH #{@with_clause}" if @with_clause
      parts << "WHERE #{@where_after_with}" if @where_after_with && @with_clause

      # SET clause for property updates
      if @set_properties
        set_parts = @set_properties.map { |k, v| "#{@alias}.#{k} = #{format_value(v)}" }
        parts << "SET #{set_parts.join(', ')}"
      end

      # REMOVE clause
      if @remove_props.any?
        remove_parts = @remove_props.map { |prop| "#{@alias}.#{prop}" }
        parts << "REMOVE #{remove_parts.join(', ')}"
      end

      # DETACH DELETE clause
      parts << "DETACH DELETE #{@alias}" if @detach_delete

      # RETURN clause
      if @return_fields.any?
        return_parts = @return_fields.map do |field|
          if field.is_a?(Symbol)
            "#{@alias}.#{field}"
          elsif field.is_a?(String)
            # Check if it's a path variable
            if @path_variable && field == @path_variable.to_s
              field
            # Check if it might be a variable from a subquery
            elsif field.match(/^\w+$/) && defined_in_query?(field)
              field
            # Handle function calls (prevent node alias prefix on CASE/function keywords)
            elsif field.start_with?('CASE ') || field.match(/^\w+\s*\(/)
              field.gsub(' as ', ' AS ')
            # Handle pattern comprehensions
            elsif field.match(/\[.+\]/)
              field.gsub(' as ', ' AS ')
            # Handle field with alias syntax
            elsif field.include?(' as ')
              modified_field = field.gsub(' as ', ' AS ')
              if modified_field.include?('.')
                modified_field
              else
                "#{@alias}.#{modified_field}"
              end
            # Handle field without dot notation
            elsif !field.include?('.')
              "#{@alias}.#{field}"
            else
              field
            end
          else
            field
          end
        end
        parts << "RETURN #{return_parts.join(', ')}"
      end

      # ORDER BY clause
      if @order_clauses.any?
        order_parts = @order_clauses.map do |clause|
          "#{@alias}.#{clause[:field]} #{clause[:direction].to_s.upcase}"
        end
        parts << "ORDER BY #{order_parts.join(', ')}"
      end

      # SKIP and LIMIT
      parts << "SKIP #{@skip_value}" if @skip_value
      parts << "LIMIT #{@limit_value}" if @limit_value

      parts.join(' ')
    end

    private

    def defined_in_query?(field)
      # Check if this is from a subquery's return
      if @call_subquery
        subquery_return = @call_subquery.instance_variable_get(:@return_fields)
        return true if subquery_return.any? do |f|
          f.is_a?(String) && (f.include?(" as #{field}") || f.include?(" AS #{field}"))
        end
      end

      # Check if it's from a WITH clause
      return true if @with_clause && (@with_clause.include?(" as #{field}") || @with_clause.include?(" AS #{field}"))

      false
    end

    def build_match_clause
      return nil if @create_properties || @merge_properties

      # Start building the initial match clause
      path_prefix = @path_variable ? "#{@path_variable} = " : ''
      initial_match = "MATCH #{path_prefix}(#{@alias}:#{@label}"

      # Add property conditions
      if @conditions.any?
        formatted_conditions = format_properties(@conditions)
        initial_match += " {#{formatted_conditions}}"
      end
      initial_match += ')'

      # Handle relationship clauses
      if @outgoing_relationship
        if @optional_match
          # For optional matches, create a separate OPTIONAL MATCH clause
          relationship_match = "OPTIONAL MATCH (#{@alias})-[:#{@outgoing_relationship}]->"
          node_text = "(#{@related_node_alias}:#{@related_node_label}"
          if @related_node_conditions.any?
            formatted_conditions = format_properties(@related_node_conditions)
            node_text += " {#{formatted_conditions}}"
          end
          node_text += ')'
          match_clause = "#{initial_match} #{relationship_match}#{node_text}"
        else
          # For regular matches, include the relationship in the initial MATCH
          relationship_text = "-[:#{@outgoing_relationship}]->"
          node_text = "(#{@related_node_alias}:#{@related_node_label}"
          if @related_node_conditions.any?
            formatted_conditions = format_properties(@related_node_conditions)
            node_text += " {#{formatted_conditions}}"
          end
          node_text += ')'
          match_clause = initial_match + relationship_text + node_text
        end
      else
        match_clause = initial_match
      end

      # Add any additional pattern matching
      match_clause += " #{@match_pattern}" if @match_pattern

      # Add raw WHERE conditions if any
      if @raw_conditions.any?
        where_conditions = @raw_conditions.map do |condition|
          # Process property references in raw conditions
          processed_condition = condition

          if condition.match(/\w+\s+(CONTAINS|STARTS WITH|ENDS WITH)\s+/)
            # Special handling for string operations
            property = condition.match(/(\w+)\s+(CONTAINS|STARTS WITH|ENDS WITH)/)[1]
            rest = condition.sub(/^\w+\s+/, '')
            processed_condition = "#{@alias}.#{property} #{rest}"
          elsif !condition.include?('(') && !condition.include?('[') && !condition.match(/\s(AND|OR|NOT|XOR|IN|IS|NULL|TRUE|FALSE)\s/)
            # Add node alias to simple property references
            processed_condition = "#{@alias}.#{condition}"
          end

          processed_condition
        end
        match_clause += " WHERE #{where_conditions.join(' AND ')}"
      end

      match_clause
    end

    # Formats properties into Cypher-compatible key-value pairs.
    # It's like JSON, but with commitment issues and worse syntax.
    def format_properties(props)
      props.map do |k, v|
        if v.is_a?(Array)
          "#{k} IN #{format_value(v)}"
        else
          "#{k}: #{format_value(v)}"
        end
      end.join(', ')
    end

    def format_value(value)
      case value
      when String
        "\"#{value}\""
      when Array
        "[#{value.map { |v| format_value(v) }.join(', ')}]"
      when Hash
        "{#{format_properties(value)}}"
      else
        value.to_s
      end
    end
  end
end
