# frozen_string_literal: true

require 'active_support/concern'
require 'concurrent'

module Cyrel
  module Parameterizable
    extend ActiveSupport::Concern

    private

    # Generates the next parameter key.
    # p1, p2, p3... it’s like a sad carnival of increasingly desperate guesses.
    def next_param_key
      @param_counter ||= 0
      @param_counter += 1
      :"p#{@param_counter}"
    end
  end
end
