# frozen_string_literal: true

require 'test_helper'

class RelationshipMergeTest < ActiveSupport::TestCase
  def setup
    PersonNode.connection.send(:wipe_database, confirm: 'yes, really')
    HobbyNode.connection.send(:wipe_database, confirm: 'yes, really')
  end

  test "id converted to integer for MemGraph" do
    alice = PersonNode.create(name: 'Alice')
    internal_id_type = alice.hobbies.cyrel_query.to_cypher[1][:p1].class
    assert_equal internal_id_type, Integer
  end
  
  test 'id left as string for MemGraph' do
    preservation_aux = CompanyNode.create(name: 'PreservationAux')
    internal_id_type = preservation_aux.call_logs.cyrel_query.to_cypher[1][:p1].class
    assert_equal internal_id_type, String
  end

  
end
