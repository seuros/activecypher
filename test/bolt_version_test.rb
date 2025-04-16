# frozen_string_literal: true

# test/bolt_version_test.rb
require 'test_helper'

class BoltVersionTest < ActiveSupport::TestCase
  include ActiveCypher::Bolt::VersionEncoding

  # 00 00 <minor> <major>
  def test_encode_version
    assert_equal "\x00\x00\x02\x05".b, encode_version(5.2)
    assert_equal "\x00\x00\x08\x05".b, encode_version(5.8)
  end

  def test_decode_version
    assert_equal 5.2, decode_version("\x00\x00\x02\x05".b)
    assert_equal 5.8, decode_version("\x00\x00\x08\x05".b)
  end

  # sanity‑check: round‑trip
  def test_roundtrip
    [5.0, 5.2, 5.4, 5.8].each do |v|
      assert_equal v, decode_version(encode_version(v))
    end
  end
end
