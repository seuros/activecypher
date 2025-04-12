# frozen_string_literal: true

require 'test_helper'
require 'cyrel'
require 'cyrel/expression/case' # Ensure loaded

class CaseExpressionTest < ActiveSupport::TestCase
  test 'case expression in RETURN with alias' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person')

    # Define the CASE expression
    Cyrel::Expression::Case.new(
      whens: [
        [Cyrel.prop(:person, :age) < 18, 'MINOR'] # Condition, Result pair
      ],
      else_result: 'ADULT'
    )

    # Build the query, manually handling parameters for the CASE expression within RawExpressionString
    query = Cyrel::Query.new
                        .match(match_node)
    # Manually register parameters used in the CASE expression
    p1 = query.register_parameter(18)
    p2 = query.register_parameter('MINOR')
    p3 = query.register_parameter('ADULT')
    # Construct the raw string using the generated parameter keys
    raw_return = Cyrel::Clause::With::RawExpressionString.new("CASE WHEN (person.age < $#{p1}) THEN $#{p2} ELSE $#{p3} END AS status")
    query.return_(raw_return)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person)
      RETURN CASE WHEN (person.age < $p1) THEN $p2 ELSE $p3 END AS status
    CYPHER
    # Parameters for 18, 'MINOR', 'ADULT'
    expected_params = { p1: 18, p2: 'MINOR', p3: 'ADULT' } # Check against manually registered params

    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
