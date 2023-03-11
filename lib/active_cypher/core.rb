# frozen_string_literal: true

module ActiveCypher
  module Core
    extend ActiveSupport::Concern
    ## define property
    # @example
    # property :name, type: String
    # property :age, type: Integer
    def self.property(name, type: String)
      define_method(name) do
        @properties[name]
      end
      define_method("#{name}=") do |value|
        @properties[name] = value
      end
    end
    attr_reader :properties

    def to_cypher
      raise NotImplementedError
    end
  end
end
