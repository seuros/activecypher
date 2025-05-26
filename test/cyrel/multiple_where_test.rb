# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class MultipleWhereTest < ActiveSupport::TestCase
  test 'multiple where calls are ANDed together' do
    match_node = Cyrel::Pattern::Node.new(:person, labels: 'Person') # No properties in MATCH
    query = Cyrel::Query.new
                        .match(match_node)
                        .where(name: 'Alice') # First where call
                        .where(age: 30) # Second where call
                        .return_(Cyrel.prop(:person, :name))

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (person:Person)
      WHERE (person.name = $p1) AND (person.age = $p2)
      RETURN person.name
    CYPHER
    expected_params = { p1: 'Alice', p2: 30 }

    assert_equal [expected_cypher, expected_params], query.to_cypher
  end
end
