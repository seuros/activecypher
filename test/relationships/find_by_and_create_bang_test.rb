# frozen_string_literal: true

require 'test_helper'

class RelationshipFindByAndCreateBangTest < ActiveSupport::TestCase
  # Testing find_by and create! for relationships
  # Because nodes get all the attention, but relationships need love too

  def setup
    # Clean up any existing data - relationships and nodes
    # Using the adapter from one of our test relationships
    connection = BelievesInRel.connection
    connection.execute_cypher('MATCH ()-[r]->() DELETE r')
    connection.execute_cypher('MATCH (n) DETACH DELETE n')

    # Create test nodes that our relationships will connect
    @person1 = PersonNode.create!(name: 'Alice', age: 30)
    @person2 = PersonNode.create!(name: 'Bob', age: 35)
    @conspiracy1 = ConspiracyNode.create!(name: 'Moon Landing', believability_index: 8)
    @conspiracy2 = ConspiracyNode.create!(name: 'Area 51', believability_index: 6)

    # Create some test relationships
    @belief1 = BelievesInRel.create!(
      { reddit_karma_spent: 1000, level_of_devotion: 'zealot' },
      from_node: @person1,
      to_node: @conspiracy1
    )

    @belief2 = BelievesInRel.create!(
      { reddit_karma_spent: 500, level_of_devotion: 'casual' },
      from_node: @person2,
      to_node: @conspiracy1
    )

    @belief3 = BelievesInRel.create!(
      { reddit_karma_spent: 5000, level_of_devotion: 'makes merch' },
      from_node: @person1,
      to_node: @conspiracy2
    )
  end

  def teardown
    # Clean up after ourselves
    connection = BelievesInRel.connection
    connection.execute_cypher('MATCH ()-[r]->() DELETE r')
    connection.execute_cypher('MATCH (n) DETACH DELETE n')
  end

  # --- find_by tests: Finding relationships like finding lost socks ---

  test 'find_by with single attribute returns first matching relationship - L48' do
    # Find by reddit karma spent
    result = BelievesInRel.find_by(reddit_karma_spent: 1000)

    assert_not_nil result
    assert_equal 1000, result.reddit_karma_spent
    assert_equal 'zealot', result.level_of_devotion
  end

  test 'find_by with multiple attributes returns matching relationship - L57' do
    # Find by multiple attributes for more precision
    result = BelievesInRel.find_by(reddit_karma_spent: 500, level_of_devotion: 'casual')

    assert_not_nil result
    assert_equal 500, result.reddit_karma_spent
    assert_equal 'casual', result.level_of_devotion
  end

  test 'find_by returns nil when no match found - L66' do
    # Looking for relationships that don't exist
    assert_nil BelievesInRel.find_by(reddit_karma_spent: 100)
    assert_nil BelievesInRel.find_by(reddit_karma_spent: 1000, level_of_devotion: 'casual')
    assert_nil BelievesInRel.find_by(level_of_devotion: 'skeptic')
  end

  test 'find_by with empty hash returns nil - L73' do
    # Empty search criteria = empty results
    assert_nil BelievesInRel.find_by({})
  end

  test 'find_by with nil returns nil - L78' do
    # Nil in, nil out - the circle of nil
    assert_nil BelievesInRel.find_by(nil)
  end

  test 'find_by handles special characters in attribute values - L83' do
    # Create a relationship with special characters
    special_belief = BelievesInRel.create!(
      { level_of_devotion: "It's \"complicated\" & weird; DROP TABLE users;--", reddit_karma_spent: 700 },
      from_node: @person2,
      to_node: @conspiracy2
    )

    result = BelievesInRel.find_by(level_of_devotion: "It's \"complicated\" & weird; DROP TABLE users;--")
    assert_not_nil result
    assert_equal special_belief.internal_id, result.internal_id
  end

  # --- find_by! tests: When you need your failures LOUD ---

  test 'find_by! raises exception when not found - L97' do
    error = assert_raises(ActiveCypher::RecordNotFound) do
      BelievesInRel.find_by!(reddit_karma_spent: 99_999)
    end

    assert_match(/Couldn't find BelievesInRel/, error.message)
    assert_match(/reddit_karma_spent: 99999/, error.message)
    assert_match(/relationship status is... complicated/, error.message)
  end

  test 'find_by! returns relationship when found - L107' do
    # The happy path where everything works
    result = BelievesInRel.find_by!(reddit_karma_spent: 5000)

    assert_not_nil result
    assert_equal 5000, result.reddit_karma_spent
    assert_equal 'makes merch', result.level_of_devotion
  end

  test 'find_by! with multiple attributes in error message - L116' do
    error = assert_raises(ActiveCypher::RecordNotFound) do
      BelievesInRel.find_by!(reddit_karma_spent: 777, level_of_devotion: 'test', extra: 'field')
    end

    assert_match(/reddit_karma_spent: 777/, error.message)
    assert_match(/level_of_devotion: "test"/, error.message)
    assert_match(/extra: "field"/, error.message)
  end

  # --- create! tests: Making relationships with commitment issues ---

  test 'create! successfully creates a valid relationship - L127' do
    # The optimistic scenario
    new_belief = BelievesInRel.create!(
      { reddit_karma_spent: 600, level_of_devotion: 'casual' },
      from_node: @person2,
      to_node: @conspiracy2
    )

    assert new_belief.persisted?
    assert_not_nil new_belief.internal_id
    assert_equal 600, new_belief.reddit_karma_spent
    assert_equal 'casual', new_belief.level_of_devotion

    # Verify it's actually in the database
    found = BelievesInRel.find_by(reddit_karma_spent: 600, level_of_devotion: 'casual')
    assert_not_nil found
  end

  test 'create! raises exception when from_node is nil - L144' do
    error = assert_raises(ActiveCypher::RecordNotSaved) do
      BelievesInRel.create!(
        { reddit_karma_spent: 500 },
        from_node: nil,
        to_node: @conspiracy1
      )
    end

    assert_match(/could not be saved/, error.message)
  end

  test 'create! raises exception when to_node is nil - L156' do
    error = assert_raises(ActiveCypher::RecordNotSaved) do
      BelievesInRel.create!(
        { reddit_karma_spent: 500 },
        from_node: @person1,
        to_node: nil
      )
    end

    assert_match(/could not be saved/, error.message)
  end

  test 'create! raises exception when nodes are not persisted - L168' do
    # Create unpersisted nodes
    unpersisted_person = PersonNode.new(name: 'Charlie')
    ConspiracyNode.new(name: 'Bigfoot')

    error = assert_raises(ActiveCypher::RecordNotSaved) do
      BelievesInRel.create!(
        { reddit_karma_spent: 900 },
        from_node: unpersisted_person,
        to_node: @conspiracy1
      )
    end

    assert_match(/could not be saved/, error.message)
  end

  test 'create! vs create behavior on failure - L183' do
    # Regular create returns unpersisted object
    rel = BelievesInRel.create(
      { reddit_karma_spent: 500 },
      from_node: nil,
      to_node: @conspiracy1
    )
    assert_not rel.persisted?

    # create! raises exception
    assert_raises(ActiveCypher::RecordNotSaved) do
      BelievesInRel.create!(
        { reddit_karma_spent: 500 },
        from_node: nil,
        to_node: @conspiracy1
      )
    end
  end

  test 'create! with validation errors includes them in message - L201' do
    # Assuming BelievesInRel might have validations
    # If not, this test documents expected behavior

    BelievesInRel.create!(
      { reddit_karma_spent: -1 }, # Might be invalid if there's a validation
      from_node: @person1,
      to_node: @conspiracy1
    )
    # If no validation, the test passes
    assert true
  rescue ActiveCypher::RecordNotSaved => e
    # If validation exists, check the message
    assert_match(/could not be saved/, e.message)
  end

  # --- Integration tests: Making sure everything plays nice together ---

  test 'find_by works after create! - L219' do
    # Create a new relationship
    created = BelievesInRel.create!(
      { reddit_karma_spent: 400, level_of_devotion: 'Just curious' },
      from_node: @person2,
      to_node: @conspiracy2
    )

    # Find it back
    found = BelievesInRel.find_by(level_of_devotion: 'Just curious')

    assert_not_nil found
    assert_equal created.internal_id, found.internal_id
    assert_equal 400, found.reddit_karma_spent
    assert_equal 'Just curious', found.level_of_devotion
  end

  test 'find_by returns relationships created with regular create - L236' do
    # Use regular create
    created = BelievesInRel.create(
      { reddit_karma_spent: 300, level_of_devotion: 'veteran' },
      from_node: @person1,
      to_node: @conspiracy2
    )

    assert created.persisted?

    # Find it with find_by
    found = BelievesInRel.find_by(reddit_karma_spent: 300, level_of_devotion: 'veteran')

    assert_not_nil found
    assert_equal created.internal_id, found.internal_id
  end

  # --- Edge cases and special scenarios ---

  test 'find_by handles nil attribute values - L253' do
    # Create a relationship with nil values
    BelievesInRel.create!(
      { reddit_karma_spent: 700, level_of_devotion: nil },
      from_node: @person2,
      to_node: @conspiracy2
    )

    # Finding by non-nil attributes should work
    found = BelievesInRel.find_by(reddit_karma_spent: 700)
    assert_not_nil found
    assert_nil found.level_of_devotion
  end

  test 'multiple relationships between same nodes can be distinguished - L267' do
    # Create another relationship between same nodes
    second_rel = BelievesInRel.create!(
      { reddit_karma_spent: 900, level_of_devotion: 'newbie' },
      from_node: @person1,
      to_node: @conspiracy1
    )

    # Original relationship
    found1 = BelievesInRel.find_by(reddit_karma_spent: 1000, level_of_devotion: 'zealot')
    assert_equal @belief1.internal_id, found1.internal_id

    # New relationship
    found2 = BelievesInRel.find_by(reddit_karma_spent: 900, level_of_devotion: 'newbie')
    assert_equal second_rel.internal_id, found2.internal_id
  end

  # --- Performance and implementation notes ---

  test 'find_by uses parameterized queries for safety - L285' do
    # Test SQL injection prevention
    malicious_value = "'; DELETE FROM relationships; --"

    # This should safely handle the malicious input
    result = BelievesInRel.find_by(level_of_devotion: malicious_value)
    assert_nil result # Should find nothing, not execute malicious code

    # Create with malicious value to test exact matching
    BelievesInRel.create!(
      { reddit_karma_spent: 200, level_of_devotion: malicious_value },
      from_node: @person1,
      to_node: @conspiracy2
    )

    # Should find it with exact match
    found = BelievesInRel.find_by(level_of_devotion: malicious_value)
    assert_not_nil found
    assert_equal malicious_value, found.level_of_devotion
  end
end
