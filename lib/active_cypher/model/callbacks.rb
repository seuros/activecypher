# frozen_string_literal: true

module ActiveCypher
  module Model
    # @note Now containing even more callback-related Ruby sorcery!
    module Callbacks
      extend ActiveSupport::Concern

      EVENTS = %i[
        initialize find create update save destroy
      ].freeze

      included do |base|
        base.define_callbacks(*EVENTS)

        %i[before after around].each do |kind|
          EVENTS.each do |evt|
            base.define_singleton_method("#{kind}_#{evt}") do |*filters, &block|
              set_callback(evt, kind, *filters, &block)
            end
          end
        end
      end

      private

      # Thin wrapper so models can do `_run(:create) { … }`
      # Because sometimes you want to feel like you’re orchestrating fate.
      # @param evt [Symbol] The callback event
      # @yield Runs inside the callback chain
      # @return [Object] The result of the block
      # Warning: This method may summon side effects from the shadow realm, or just invoke a little callback necromancy when you least expect it.
      def _run(evt) = run_callbacks(evt) { yield if block_given? }
    end
  end
end
