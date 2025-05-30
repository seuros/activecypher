# frozen_string_literal: true

require 'test_helper'

class PackstreamBigDecimalTest < ActiveSupport::TestCase
  test 'can pack and unpack BigDecimal values' do
    decimal = BigDecimal('123.456')

    # Pack the value - BigDecimal is serialized as string
    packed = ActiveCypher::Bolt::Packstream.pack(decimal)

    # Unpack and verify - comes back as string due to protocol limitations
    unpacked = ActiveCypher::Bolt::Packstream.unpack(packed)

    assert_equal decimal.to_s('F'), unpacked
    assert_instance_of String, unpacked
  end

  test 'can pack and unpack zero BigDecimal' do
    decimal = BigDecimal('0.0')

    packed = ActiveCypher::Bolt::Packstream.pack(decimal)
    unpacked = ActiveCypher::Bolt::Packstream.unpack(packed)

    assert_equal decimal.to_s('F'), unpacked
    assert_instance_of String, unpacked
  end

  test 'can pack and unpack negative BigDecimal' do
    decimal = BigDecimal('-456.789')

    packed = ActiveCypher::Bolt::Packstream.pack(decimal)
    unpacked = ActiveCypher::Bolt::Packstream.unpack(packed)

    assert_equal decimal.to_s('F'), unpacked
    assert_instance_of String, unpacked
  end

  test 'can pack and unpack very large BigDecimal' do
    decimal = BigDecimal('123456789012345678901234567890.123456789')

    packed = ActiveCypher::Bolt::Packstream.pack(decimal)
    unpacked = ActiveCypher::Bolt::Packstream.unpack(packed)

    assert_equal decimal.to_s('F'), unpacked
    assert_instance_of String, unpacked
  end

  test 'can pack and unpack very small BigDecimal' do
    decimal = BigDecimal('0.000000000000000000000000000001')

    packed = ActiveCypher::Bolt::Packstream.pack(decimal)
    unpacked = ActiveCypher::Bolt::Packstream.unpack(packed)

    assert_equal decimal.to_s('F'), unpacked
    assert_instance_of String, unpacked
  end

  test 'BigDecimal maintains precision during pack/unpack cycle' do
    # Test that precision is preserved exactly
    decimal = BigDecimal('12345.67890123456789')

    packed = ActiveCypher::Bolt::Packstream.pack(decimal)
    unpacked = ActiveCypher::Bolt::Packstream.unpack(packed)

    assert_equal decimal.to_s('F'), unpacked
    assert_instance_of String, unpacked
    # Verify that the string can be converted back to BigDecimal with same value
    assert_equal decimal, BigDecimal(unpacked)
  end
end
