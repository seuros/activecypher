# frozen_string_literal: true

# # frozen_string_literal: true

# require 'test_helper'

# module ActiveCypher
#   module Bolt
#     class DriverConnectionTest < ActiveSupport::TestCase
#       test 'successful HELLO handshake' do
#         ActiveCypherTest::DriverHarness.driver.with_session do |session|
#           assert_predicate session.connection, :connected?
#           assert_match(/Neo4j|Memgraph/, session.server_agent)
#           assert_equal [{ n: 1 }], session.run('RETURN 1 AS n').to_a
#         end
#       end
#     end
#   end
# end
