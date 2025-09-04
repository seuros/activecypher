# frozen_string_literal: true

class NumericTestNode < ApplicationGraphNode
  attribute :integer_value, :integer
  attribute :float_value, :float
  attribute :decimal_value, :decimal
  attribute :name, :string

  validates :name, presence: true
end