# frozen_string_literal: true

module ActiveCypher
  module Fixtures
    # Parses a fixture profile file using instance_eval in a DSL context.
    class Parser
      attr_reader :file, :dsl_context

      def initialize(file)
        @file = file
        @dsl_context = ActiveCypher::Fixtures::DSLContext.new
      end

      # Evaluates the profile file in the DSL context.
      # Returns the DSLContext instance (which accumulates node/rel declarations).
      def parse
        code = File.read(file)
        dsl_context.instance_eval(code, file)
        dsl_context
      end
    end
  end
end
