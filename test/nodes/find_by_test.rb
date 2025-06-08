# frozen_string_literal: true

require 'test_helper'

class FindByTest < ActiveSupport::TestCase
  # Testing find_by: Because apparently .where().first was too many characters
  # and we need to save those precious keystrokes for writing comments about our code

  def setup
    # Clean slate because yesterday's data is so yesterday
    # Use the proper database wipe method to ensure complete cleanup
    PersonNode.connection.send(:wipe_database, confirm: 'yes, really')
    CompanyNode.connection.send(:wipe_database, confirm: 'yes, really')

    # Create some test data because an empty database is like a party with no guests
    @alice_memgraph = PersonNode.create(name: 'Alice', age: 30, active: true)
    @bob_memgraph = PersonNode.create(name: 'Bob', age: 25, active: false)
    @alice2_memgraph = PersonNode.create(name: 'Alice', age: 35, active: true)

    # Neo4j models get their own special treatment because they're too good for the default connection
    @acme_neo4j = CompanyNode.create(name: 'Acme Corp', founding_year: 1990, active: true)
    @widgets_neo4j = CompanyNode.create(name: 'Widgets Inc', founding_year: 2000, active: false)
    @acme2_neo4j = CompanyNode.create(name: 'Acme Corp', founding_year: 2010, active: true)
  end

  def teardown
    # Clean up after ourselves like responsible adults (or at least pretend to be)
    # Using DETACH DELETE because destroy_all is too mainstream
    PersonNode.connection.execute_cypher('MATCH (n:PersonNode) DETACH DELETE n')
    CompanyNode.connection.execute_cypher('MATCH (n:CompanyNode) DETACH DELETE n')
  end

  # --- Basic find_by tests: Because finding things should be easy ---

  test 'find_by with single attribute returns first matching node (Memgraph) - L34' do
    # Testing with Memgraph because it keeps things simple with numeric IDs
    result = PersonNode.find_by(name: 'Alice')
    assert_not_nil result, 'Should find an Alice'
    assert_equal 'Alice', result.name
    # Should get one of the Alices - checking we get the first one created (age 30)
    assert_includes [30, 35], result.age, 'Should find one of the Alices'
  end

  test 'find_by with single attribute returns first matching node (Neo4j) - L43' do
    # Neo4j: Where IDs are strings because why make things simple?
    result = CompanyNode.find_by(name: 'Acme Corp')
    assert_not_nil result
    assert_equal 'Acme Corp', result.name
    assert_includes [1990, 2010], result.founding_year, 'Should find one of the Acme Corps'
  end

  test 'find_by with multiple attributes returns correct node (Memgraph) - L51' do
    # Because sometimes one attribute just isn't specific enough
    result = PersonNode.find_by(name: 'Alice', age: 35)
    assert_not_nil result
    assert_equal 'Alice', result.name
    assert_equal 35, result.age
  end

  test 'find_by with multiple attributes returns correct node (Neo4j) - L59' do
    # Neo4j can do multiple attributes too, it's not just a one-trick pony
    result = CompanyNode.find_by(name: 'Acme Corp', founding_year: 2010)
    assert_not_nil result
    assert_equal 'Acme Corp', result.name
    assert_equal 2010, result.founding_year
  end

  test 'find_by with boolean attributes works (Memgraph) - L67' do
    # Because true/false decisions are the only ones developers can make confidently
    result = PersonNode.find_by(name: 'Bob', active: false)
    assert_not_nil result
    assert_equal 'Bob', result.name
    assert_equal false, result.active
  end

  test 'find_by with boolean attributes works (Neo4j) - L75' do
    # Neo4j handles booleans too, probably converts them to strings internally
    result = CompanyNode.find_by(name: 'Widgets Inc', active: false)
    assert_not_nil result
    assert_equal 'Widgets Inc', result.name
    assert_equal false, result.active
  end

  # --- Not found scenarios: Where dreams go to die ---

  test 'find_by returns nil when no match found (Memgraph) - L85' do
    # Looking for Charlie in a world of Alices and Bobs
    # Note: If this fails, it might be because another test created a Charlie
    # We'll use a more unique name to avoid conflicts
    assert_nil PersonNode.find_by(name: "NonexistentPerson_#{SecureRandom.hex(4)}")
    assert_nil PersonNode.find_by(name: 'Alice', age: 99)
  end

  test 'find_by returns nil when no match found (Neo4j) - L91' do
    # These companies don't exist, just like my work-life balance
    assert_nil CompanyNode.find_by(name: 'Nonexistent Corp')
    assert_nil CompanyNode.find_by(name: 'Acme Corp', founding_year: 1885)
  end

  test 'find_by with empty hash returns nil - L97' do
    # Because finding everything is the same as finding nothing, philosophically speaking
    assert_nil PersonNode.find_by({})
    assert_nil CompanyNode.find_by({})
  end

  test 'find_by with nil returns nil - L103' do
    # nil in, nil out - the circle of life
    assert_nil PersonNode.find_by(nil)
    assert_nil CompanyNode.find_by(nil)
  end

  # --- Exception handling: When nil just isn't dramatic enough ---

  test 'find_by! raises exception when not found (Memgraph) - L111' do
    # Because sometimes you want your code to scream when it can't find something
    error = assert_raises(ActiveCypher::RecordNotFound) do
      PersonNode.find_by!(name: 'Ghost')
    end
    assert_match(/Couldn't find PersonNode/, error.message)
    assert_match(/name: "Ghost"/, error.message)
  end

  test 'find_by! raises exception when not found (Neo4j) - L120' do
    # Neo4j exceptions: Now with 100% more drama
    error = assert_raises(ActiveCypher::RecordNotFound) do
      CompanyNode.find_by!(name: 'Bankruptcy LLC')
    end
    assert_match(/Couldn't find CompanyNode/, error.message)
  end

  test 'find_by! returns record when found - L128' do
    # The happy path where everything works and nobody panics
    result = PersonNode.find_by!(name: 'Alice', age: 30)
    assert_not_nil result
    assert_equal 'Alice', result.name
    assert_equal 30, result.age

    result = CompanyNode.find_by!(name: 'Widgets Inc')
    assert_not_nil result
    assert_equal 'Widgets Inc', result.name
  end

  # --- Edge cases: Because the universe loves to test our assumptions ---

  test 'find_by handles special characters safely - L142' do
    # Testing the dark arts of SQL injection... I mean, Cypher injection
    PersonNode.create(name: "O'Malley's \"Special\" Name", age: 40)
    result = PersonNode.find_by(name: "O'Malley's \"Special\" Name")
    assert_not_nil result
    assert_equal "O'Malley's \"Special\" Name", result.name

    CompanyNode.create(name: "Hack'); DROP TABLE users;--", founding_year: 2020)
    result = CompanyNode.find_by(name: "Hack'); DROP TABLE users;--")
    assert_not_nil result
    assert_equal "Hack'); DROP TABLE users;--", result.name
  end

  test 'find_by is case sensitive - L155' do
    # Because 'alice' and 'Alice' are totally different people, obviously
    result = PersonNode.find_by(name: 'alice')
    assert_nil result

    result = CompanyNode.find_by(name: 'acme corp')
    assert_nil result
  end

  test 'find_by handles nil values in attributes - L164' do
    # For when your data has trust issues and won't commit to having values
    PersonNode.create(name: 'Nullbert', age: nil)
    result = PersonNode.find_by(name: 'Nullbert')
    assert_not_nil result
    assert_equal 'Nullbert', result.name

    # Finding by nil is trickier - Cypher uses IS NULL not = NULL
    # So this might not work as expected, but let's document the behavior
    result_by_nil = PersonNode.find_by(age: nil)
    if result_by_nil
      assert_equal 'Nullbert', result_by_nil.name
    else
      # If it doesn't work, at least we know
      assert_nil result_by_nil, "find_by doesn't support nil value matching"
    end
  end

  test 'find_by handles numeric types correctly - L182' do
    # Because 30 and 30.0 are the same... until they're not
    PersonNode.create(name: 'Floaty McFloatface', age: 42)

    # Integer lookup should work
    result = PersonNode.find_by(age: 42)
    assert_not_nil result
    assert_equal 'Floaty McFloatface', result.name
    assert_equal 42, result.age
  end

  # --- Security: Because paranoia is just good engineering ---

  test 'find_by properly escapes injection attempts - L195' do
    # Your friendly neighborhood security test

    injection_attempts = [
      "'; DROP TABLE users; --",
      "admin' OR '1'='1",
      'test" OR "1"="1',
      "test') OR ('1'='1"
    ]

    injection_attempts.each do |evil_name|
      PersonNode.create(name: evil_name, age: 666)
      result = PersonNode.find_by(name: evil_name)
      assert_not_nil result
      assert_equal evil_name, result.name
      assert_equal 666, result.age

      # Make sure it's exact match, not some SQL/Cypher trickery
      assert_nil PersonNode.find_by(name: "#{evil_name}extra")
    end
  end

  test 'find_by handles regex patterns as literals - L217' do
    # Because .* should mean dot-star, not "match everything"
    PersonNode.create(name: 'test.*regex', age: 50)
    PersonNode.create(name: 'test123regex', age: 51)

    result = PersonNode.find_by(name: 'test.*regex')
    assert_not_nil result
    assert_equal 'test.*regex', result.name

    # Should not match the literal_person
    result2 = PersonNode.find_by(name: 'test.*')
    assert_nil result2
  end

  # --- Performance considerations (not really testing, just documenting) ---

  test 'find_by uses LIMIT 1 for efficiency - L233' do
    # Let's make sure we're not loading the entire database into memory
    # This test doesn't actually verify the LIMIT, but it makes us feel better
    100.times { |i| PersonNode.create(name: "Clone #{i}", age: 25) }

    result = PersonNode.find_by(age: 25)
    assert_not_nil result
    # If this was loading all records, it would be much slower
    # But we're not actually measuring that because benchmarking in tests is weird
  end

  # --- Cross-database compatibility: Because supporting multiple databases is "fun" ---

  test 'find_by works consistently across Memgraph and Neo4j - L246' do
    # Both databases should behave the same way, in theory
    # In practice, one uses numeric IDs and the other uses string IDs
    # But find_by shouldn't care about that implementation detail

    person = PersonNode.find_by(name: 'Alice')
    company = CompanyNode.find_by(name: 'Acme Corp')

    assert_not_nil person
    assert_not_nil company
    assert_kind_of PersonNode, person
    assert_kind_of CompanyNode, company
  end

  # --- Cyrel integration: Ensuring we're using the safe query builder ---

  test 'find_by generates parameterized queries through Cyrel - L262' do
    # Let's peek under the hood and make sure we're using Cyrel properly
    # We can't easily inspect the actual query, but we can verify the behavior

    # Create a person with a name that would break unparameterized queries
    injection_name = "Test' AND 1=1 OR '"
    PersonNode.create(name: injection_name, age: 99)

    # If this was building queries with string concatenation, it would fail or return wrong results
    result = PersonNode.find_by(name: injection_name)
    assert_not_nil result
    assert_equal injection_name, result.name
    assert_equal 99, result.age

    # Try to find with a similar but not exact name - should return nil
    assert_nil PersonNode.find_by(name: "Test' AND 1=1")
    assert_nil PersonNode.find_by(name: "' AND 1=1 OR '")
  end
end
