# frozen_string_literal: true

require 'test_helper'

# ------------------------------------------------------------------
# Relationship subclass that wires a few callbacks so we can assert
# they actually fire.
# ------------------------------------------------------------------
class CallbackOwnsPetRelationship < OwnsPetRelationship
  attribute :state, :string

  before_create  ->(rel) { rel.state = 'before_create'  }
  after_create   ->(rel) { rel.state = 'after_create'   }

  # Abort any attempt to destroy this edge
  before_destroy -> { throw :abort }
end

# ------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------
class RelationshipCallbacksTest < ActiveSupport::TestCase
  def setup
    @owner = PersonNode.create(name: 'Alice')
    @pet   = PetNode.create(name: 'Bubbles', species: 'Fish')
  end

  def teardown
    # Clean‑up so other tests don't choke on residual data
    @owner.destroy if @owner&.persisted?
    @pet.destroy   if @pet&.persisted?
  end

  test 'before_create and after_create both run' do
    rel = CallbackOwnsPetRelationship.new(from_node: @owner, to_node: @pet)

    assert rel.save, 'relationship should save successfully'
    assert_equal 'after_create', rel.state, 'after_create should overwrite before_create flag'
    assert rel.persisted?, 'relationship must now be persisted'
  end

  test 'before_destroy can abort destruction' do
    rel = CallbackOwnsPetRelationship.create(from_node: @owner, to_node: @pet)

    refute rel.destroy, 'destroy should be halted by before_destroy'
    assert rel.persisted?, 'relationship should still be in DB after abort'
  end
end
