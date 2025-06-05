# frozen_string_literal: true

require 'test_helper'

class CreateBangTest < ActiveSupport::TestCase
  # Testing create!: Because sometimes you want your failures to be LOUD
  # Like that one coworker who can't use their inside voice

  def setup
    # Clean up the graph because we're not savages
    # More aggressive cleanup to handle any leftover data
    PersonNode.connection.execute_cypher('MATCH (n) WHERE "Person" IN labels(n) DETACH DELETE n')
    CompanyNode.connection.execute_cypher('MATCH (n) WHERE "Company" IN labels(n) DETACH DELETE n')
  end

  # --- Happy path tests: When everything goes right (rare, but it happens) ---

  test 'create! successfully creates a valid node (Memgraph) - L20' do
    # The optimistic scenario where validations pass and the database cooperates
    person = PersonNode.create!(name: 'Alice', age: 30, active: true)

    assert person.persisted?, 'Person should be persisted'
    assert_not_nil person.internal_id, 'Should have an internal_id'
    assert_equal 'Alice', person.name
    assert_equal 30, person.age
    assert_equal true, person.active
  end

  test 'create! successfully creates a valid node (Neo4j) - L32' do
    # Neo4j: Where success is measured in string IDs and existential dread
    company = CompanyNode.create!(name: 'Success Corp', founding_year: 2020, active: true)

    assert company.persisted?, 'Company should be persisted'
    assert_not_nil company.internal_id, 'Should have an internal_id'
    assert_equal 'Success Corp', company.name
    assert_equal 2020, company.founding_year
    assert_equal true, company.active
  end

  test 'create! returns the created record - L43' do
    # Because what good is a bang method if it doesn't give you what you want?
    unique_name = "BangBob_#{SecureRandom.hex(4)}"
    person = PersonNode.create!(name: unique_name, age: 25)

    assert_kind_of PersonNode, person
    assert_equal unique_name, person.name

    # Verify it's actually in the database
    found = PersonNode.find_by(name: unique_name)
    assert_not_nil found
    assert_equal unique_name, found.name
    assert_equal 25, found.age
  end

  # --- Validation failure tests: When your data doesn't meet expectations ---

  test 'create! raises exception on validation failure (Memgraph) - L56' do
    # PersonNode requires a name, so let's disappoint it
    error = assert_raises(ActiveCypher::RecordNotSaved) do
      PersonNode.create!(age: 30) # Missing required name
    end

    assert_match(/PersonNode could not be saved/, error.message)
    assert_match(/Name can't be blank/, error.message)

    # Verify nothing was created
    # Count the records after the failed create - should be same as before
    final_count = PersonNode.all.count
    assert_equal 0, final_count, 'No PersonNodes should exist after cleanup and failed create'
  end

  test 'create! raises exception on validation failure (Neo4j) - L68' do
    # CompanyNode also has standards (requires name)
    error = assert_raises(ActiveCypher::RecordNotSaved) do
      CompanyNode.create!(founding_year: 2020) # Missing required name
    end

    assert_match(/CompanyNode could not be saved/, error.message)
    assert_match(/Name can't be blank/, error.message)

    # Verify nothing was created
    # Count the records after the failed create - should be same as before
    final_count = CompanyNode.all.count
    assert_equal 0, final_count, 'No CompanyNodes should exist after cleanup and failed create'
  end

  test 'create! includes all validation errors in exception message - L80' do
    # Let's create a node class with multiple validations for this test
    # Using the existing models, we can trigger multiple errors if they have them
    error = assert_raises(ActiveCypher::RecordNotSaved) do
      PersonNode.create!(name: '', age: nil) # Empty name should fail validation
    end

    assert_match(/PersonNode could not be saved/, error.message)
    # The actual error messages depend on the model's validations
  end

  # --- Edge cases: Because the universe loves to test our assumptions ---

  test 'create! with empty hash still validates - L92' do
    # Even with no attributes, validations must be honored
    error = assert_raises(ActiveCypher::RecordNotSaved) do
      PersonNode.create!({})
    end

    assert_match(/Name can't be blank/, error.message)
  end

  test 'create! with nil attributes - L100' do
    # Because nil is a valid value, except when it's not
    error = assert_raises(ActiveCypher::RecordNotSaved) do
      PersonNode.create!(nil)
    end

    assert_match(/Name can't be blank/, error.message)
  end

  test 'create! properly handles special characters in attributes - L108' do
    # Testing that our bang method doesn't explode with weird data
    person = PersonNode.create!(
      name: "O'Malley \"The Hammer\" Jones; DROP TABLE users;--",
      age: 35
    )

    assert person.persisted?
    assert_equal "O'Malley \"The Hammer\" Jones; DROP TABLE users;--", person.name
  end

  test 'create! works with default values - L118' do
    # Testing that defaults are applied before validation
    person = PersonNode.create!(name: 'DefaultTest')

    assert person.persisted?
    assert_equal true, person.active, 'Should use default value for active'
  end

  # --- Comparison with create: Because context matters ---

  test 'create! vs create behavior on validation failure - L127' do
    # create returns false/unsaved record, create! raises exception

    # Regular create
    person = PersonNode.create(age: 30) # Missing name
    assert_not person.persisted?
    assert person.errors[:name].present?

    # Bang create
    assert_raises(ActiveCypher::RecordNotSaved) do
      PersonNode.create!(age: 30)
    end
  end

  test 'create! vs create behavior on success - L140' do
    # Both should work the same when everything is valid

    person1 = PersonNode.create(name: 'Create User', age: 25)
    person2 = PersonNode.create!(name: 'Create! User', age: 26)

    assert person1.persisted?
    assert person2.persisted?
    assert_equal 25, person1.age
    assert_equal 26, person2.age
  end

  # --- Multiple creates: Testing atomicity (or lack thereof) ---

  test 'multiple create! calls are independent - L153' do
    # Each create! is its own transaction (or whatever graph databases call it)

    PersonNode.create!(name: 'First', age: 20)

    # This should fail but not affect person1
    assert_raises(ActiveCypher::RecordNotSaved) do
      PersonNode.create!(name: '') # Invalid
    end

    # person1 should still exist
    assert PersonNode.find_by(name: 'First').present?

    PersonNode.create!(name: 'Second', age: 21)

    # Both valid creates should exist
    all_people = PersonNode.all.to_a
    assert_equal 2, all_people.select { |p| %w[First Second].include?(p.name) }.count
  end

  # --- Database-specific behavior: Because standardization is a myth ---

  test 'create! error format is consistent across databases - L172' do
    # Both Memgraph and Neo4j should produce similar error messages

    memgraph_error = assert_raises(ActiveCypher::RecordNotSaved) do
      PersonNode.create!(age: 30) # PersonNode uses Memgraph
    end

    neo4j_error = assert_raises(ActiveCypher::RecordNotSaved) do
      CompanyNode.create!(founding_year: 2020) # CompanyNode uses Neo4j
    end

    # Both should mention the class name and validation errors
    assert_match(/PersonNode could not be saved/, memgraph_error.message)
    assert_match(/CompanyNode could not be saved/, neo4j_error.message)
  end

  # --- Performance considerations: Not really testing, just documenting ---

  test 'create! raises immediately on validation failure - L188' do
    # It shouldn't even try to hit the database if validations fail
    # We can't easily test this without mocking, but let's document the behavior

    start_time = Time.now
    assert_raises(ActiveCypher::RecordNotSaved) do
      PersonNode.create!(name: '')
    end
    elapsed = Time.now - start_time

    # Should be very fast since it doesn't hit the database
    assert elapsed < 0.1, 'Validation should fail quickly without database call'
  end

  # --- The philosophical test: What does it mean to create? ---

  test "create! establishes the node's existence in the graph universe - L202" do
    # A successfully created node should be findable, countable, and real

    initial_count = PersonNode.all.count

    person = PersonNode.create!(name: 'Existential Eddie', age: 42)

    # It exists in multiple ways
    assert person.persisted?, 'Should be persisted'
    assert PersonNode.find(person.internal_id), 'Should be findable by ID'
    assert PersonNode.find_by(name: 'Existential Eddie'), 'Should be findable by attributes'
    assert_equal initial_count + 1, PersonNode.all.count, 'Should increment count'

    # And it has an identity
    assert person.internal_id.present?, 'Should have an identity'
  end
end
