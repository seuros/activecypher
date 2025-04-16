# frozen_string_literal: true

# # frozen_string_literal: true

# # test/callbacks_test.rb
# require 'test_helper'

# class CallbacksTest < ActiveSupport::TestCase
#   test 'create callbacks run' do
#     person = CallbackPerson.create(name: 'Alice')
#     assert_equal 'after', person.flag
#   end

#   test 'before_destroy can abort' do
#     person = CallbackPerson.create(name: 'Bob')
#     refute person.destroy
#     assert person.persisted?
#   end
# end
