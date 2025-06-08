# frozen_string_literal: true

require 'test_helper'

# Testing relationship validations: Because even in graph databases,
# love triangles are complicated and someone's going to get hurt.
class RelationshipValidationTest < ActiveSupport::TestCase
  # Clean the database before each test because yesterday's drama shouldn't affect today's heartbreak
  def setup
    PersonNode.connection.send(:wipe_database, confirm: 'yes, really')
    HobbyNode.connection.send(:wipe_database, confirm: 'yes, really')
  end

  test 'save! raises helpful error when relationship creation fails' do
    # Alice tries to create a relationship with imaginary people (classic mistake)
    # But forgets that nil people make for terrible relationships. It's like dating a ghost.
    rel = EnjoysRel.new(
      from_node: nil,
      to_node: nil,
      frequency: 'desperately',
      since: Date.today
    )

    # This should fail spectacularly, like most of Alice's dating attempts
    # The failure happens during save because you can't create relationships with nil nodes
    error = assert_raises(ActiveCypher::RecordNotSaved) do
      rel.save!
    end

    # The error message should mention the class name
    assert_match(/EnjoysRel could not be saved/, error.message)
    assert_match(/relationship was never meant to be/, error.message)

    # Should still be a new record because love didn't find a way
    assert rel.new_record?, 'Should still be a new record after failed save'
  end

  test 'validation prevents creating relationships with suspicious frequency' do
    # Alice tries to date someone "obsessively" but our validation has standards
    alice = PersonNode.create(name: 'Alice', age: 28)
    bob = PersonNode.create(name: 'Bob', age: 30)

    # Try to create dating relationship with invalid frequency
    # Like Alice trying to date "obsessively" - that's just unhealthy
    rel = DatingRel.new(
      from_node: alice,
      to_node: bob,
      frequency: 'obsessively', # Not in our allowed list
      since: Date.today
    )

    # save! should fail with validation error
    error = assert_raises(ActiveCypher::RecordNotSaved) do
      rel.save!
    end

    # Should get a helpful validation error
    assert_match(/DatingRel could not be saved/, error.message)
    assert_match(/We have standards/, error.message)
  end

  test 'validation can check for required nodes like a good wingman' do
    # Bob tries to start dating but forgets to bring his date
    # It's like showing up to a restaurant reservation for two, alone
    bob = PersonNode.create(name: 'Bob', age: 25)

    # Bob forgets to specify who he's dating
    rel = DatingRel.new(
      from_node: bob,
      to_node: nil, # Oops, Bob's date stood him up (or never existed)
      frequency: 'desperately',
      since: Date.today
    )

    # save! should throw a tantrum like Bob when he realizes he's dining alone
    error = assert_raises(ActiveCypher::RecordNotSaved) do
      rel.save!
    end

    assert_match(/DatingRel could not be saved/, error.message)
    assert_match(/relationships require TWO people/, error.message)
  end

  test 'validation errors are properly accumulated like relationship baggage' do
    # Alice tries to create a doomed dating relationship with multiple problems
    # Like her dating history, it's a series of poor choices
    alice = PersonNode.create(name: 'Alice', age: 30)
    bob = PersonNode.create(name: 'Bob', age: 28)

    # Create a doomed dating relationship that violates multiple validations
    rel = DatingRel.new(
      from_node: alice,
      to_node: bob,
      frequency: nil, # Missing frequency - violates inclusion validation
      since: nil, # Missing start date - violates presence validation
      drama_level: 11 # Triggers the custom "doomed" validation
    )

    error = assert_raises(ActiveCypher::RecordNotSaved) do
      rel.save!
    end

    # Should mention the validation failures
    assert_match(/DatingRel could not be saved/, error.message)

    # Check that the relationship collected all its baggage (validation errors)
    assert_not rel.errors.empty?, 'Should have validation errors'
    assert rel.errors[:frequency].any?, 'Should have frequency validation errors'
    assert rel.errors[:since].any?, 'Should have since validation errors'
    assert rel.errors[:base].any?, 'Should have custom validation errors'
  end
end
