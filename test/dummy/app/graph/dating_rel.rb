# frozen_string_literal: true

# Alice's comprehensive dating relationship - covers all validation scenarios
# Because dating is complicated and so are our business rules
class DatingRel < ApplicationGraphRelationship
  from_class 'PersonNode'
  to_class 'PersonNode'
  type 'DATING'

  attribute :frequency, :string, default: 'complicated'
  attribute :since, :date
  attribute :status, :string, default: 'new'
  attribute :drama_level, :integer, default: 5

  # Frequency validation - Alice has standards
  validates :frequency, inclusion: {
    in: %w[daily weekly monthly occasionally never seriously],
    message: 'is not a valid frequency. We have standards, you know.'
  }

  # Node presence validations - relationships require two people
  validates :from_node, presence: { message: "can't be missing - someone has to start this!" }
  validates :to_node, presence: { message: "can't be missing - relationships require TWO people!" }

  # Date validation for testing multiple errors
  validates :since, presence: { message: "can't be blank - when did this beautiful disaster start?" }

  # Custom validation for testing accumulated errors
  validate :sometimes_doomed

  private

  def sometimes_doomed
    # Only fail if drama_level is set to 11 (for testing multiple validation failures)
    return unless drama_level == 11

    errors.add(:base, 'This relationship is doomed from the start, like Ross and Rachel.')
  end
end
