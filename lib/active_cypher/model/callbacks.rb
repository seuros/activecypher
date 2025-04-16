# frozen_string_literal: true

module ActiveCypher
  # <= matches your other concerns
  module Model
    # @!parse
    #   # Model::Callbacks provides lifecycle hooks for your models, so you can pretend you have control over what happens and when.
    #   # Because nothing says "enterprise" like a callback firing at just the wrong moment.
    #   # Under the hood, it’s all just a little bit of Ruby sorcery, callback witchcraft, and the occasional forbidden incantation from the callback crypt.
    module Callbacks
      extend ActiveSupport::Concern

      EVENTS = %i[
        initialize find validate create update save destroy
      ].freeze

      included do
        include ActiveSupport::Callbacks
        define_callbacks(*EVENTS)
      end

      class_methods do
        %i[before after around].each do |kind|
          EVENTS.each do |evt|
            define_method("#{kind}_#{evt}") do |*filters, &block|
              # This is where the callback coven gathers to cast their hooks.
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
