# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class ConditionalAndLiteralConstructsTest < ActiveSupport::TestCase
  # Removed duplicate CASE Expression test (covered in case_expression_test.rb)

  test 'List and Map Literals in RETURN with Aliases' do
    list_literal = [1, 2, 3]
    map_literal = { name: 'Jane', age: 22 }

    # Use RawExpressionString to handle the literal representation + alias
    # Parameters will be generated for the list and map values.
    return_list = Cyrel::Clause::With::RawExpressionString.new('$p1 AS numbers')
    return_map = Cyrel::Clause::With::RawExpressionString.new('$p2 AS personData')

    query = Cyrel::Query.new
                        # Register the literals to get parameter names p1, p2
                        .tap do |q|
      q.register_parameter(list_literal)
      q.register_parameter(map_literal)
    end
                        .return_(return_list, return_map)

    expected_cypher = <<~CYPHER.chomp.strip
      RETURN $p1 AS numbers, $p2 AS personData
    CYPHER
    # The parameters hold the actual list and map
    expected_params = { p1: [1, 2, 3], p2: { name: 'Jane', age: 22 } }

    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
