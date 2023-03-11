# frozen_string_literal: true

module ActiveCypher
  module Database
    extend ActiveSupport::Concern
    attr_reader :database
  end
end
