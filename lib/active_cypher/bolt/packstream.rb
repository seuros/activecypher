# frozen_string_literal: true

require 'stringio'

module ActiveCypher
  module Bolt
    # Handles Packstream serialization and deserialization.
    # Based on Bolt Protocol Specification version 5.0
    # https://7687.org/bolt/bolt-protocol-specification-5.0.html#packstream-structures
    module Packstream
      # Marker Bytes & Limits
      TINY_STRING_MARKER_BASE = 0x80
      STRING_8_MARKER = 0xD0
      STRING_16_MARKER = 0xD1
      # STRING_32_MARKER = 0xD2

      TINY_LIST_MARKER_BASE = 0x90 # Added List marker base
      LIST_8_MARKER = 0xD4       # Added List marker
      LIST_16_MARKER = 0xD5      # Added List marker
      # LIST_32_MARKER = 0xD6      # Added List marker
      # STRING_32_MARKER = 0xD2 # Not implementing 32-bit sizes for now

      TINY_MAP_MARKER_BASE = 0xA0
      MAP_8_MARKER = 0xD8
      MAP_16_MARKER = 0xD9
      # MAP_32_MARKER = 0xDA # Not implementing 32-bit sizes for now

      INT_8 = 0xC8
      INT_16 = 0xC9
      INT_32 = 0xCA
      INT_64 = 0xCB

      TINY_INT_MIN = -16
      TINY_INT_MAX = 127
      INT_8_MIN = -128
      INT_8_MAX = 127
      INT_16_MIN = -32_768
      INT_16_MAX = 32_767
      INT_32_MIN = -2_147_483_648
      INT_32_MAX = 2_147_483_647
      # INT_64 limits are typically Ruby's standard Integer limits

      # Packs Ruby objects into Packstream byte format.
      class Packer
        # Define constants inside Packer where they are used
        NULL = 0xC0
        FALSEY = 0xC2
        TRUETHY = 0xC3

        def initialize(io)
          @io = io
        end

        def pack(value)
          case value
          when String then pack_string(value)
          when Hash then pack_map(value)
          when Integer then pack_integer(value)
          when TrueClass then write_marker([TRUETHY].pack('C'))
          when FalseClass then write_marker([FALSEY].pack('C'))
          when NilClass then write_marker([NULL].pack('C'))
          when Array then pack_list(value)
          # TODO: Add other types as needed (Float, Structure)
          else
            raise ProtocolError, "Cannot pack type: #{value.class}"
          end
        end

        private

        def pack_string(str)
          bytes = str.encode('UTF-8')
          size = bytes.bytesize

          if size < 16 # TinyString
            write_marker_and_data([TINY_STRING_MARKER_BASE | size].pack('C'), bytes)
          elsif size < 256 # STRING_8
            write_marker_and_data([STRING_8_MARKER, size].pack('CC'), bytes)
          elsif size < 65_536 # STRING_16
            write_marker_and_data([STRING_16_MARKER, size].pack('Cn'), bytes)
          else
            raise ProtocolError, "String too large to pack (size: #{size})"
            # write_marker_and_data([STRING_32_MARKER, size].pack('CN>'), bytes)
          end
        end

        def pack_map(map)
          size = map.size

          if size < 16 # TinyMap
            write_marker([TINY_MAP_MARKER_BASE | size].pack('C'))
          elsif size < 256 # MAP_8
            write_marker([MAP_8_MARKER, size].pack('CC'))
          elsif size < 65_536 # MAP_16
            write_marker([MAP_16_MARKER, size].pack('Cn'))
          else
            raise ProtocolError, "Map too large to pack (size: #{size})"
            # write_marker([MAP_32_MARKER, size].pack('CN>'))
          end

          map.each do |key, value|
            pack(key.to_s) # Keys must be strings
            pack(value)
          end
        end

        def pack_list(list)
          size = list.size
          if size < 16 # TinyList
            write_marker([TINY_LIST_MARKER_BASE | size].pack('C'))
          elsif size < 256 # LIST_8
            write_marker([LIST_8_MARKER, size].pack('CC'))
          elsif size < 65_536 # LIST_16
            write_marker([LIST_16_MARKER, size].pack('Cn')) # n is already network byte order
          else
            raise ProtocolError, "List too large to pack (size: #{size})"
            # write_marker([LIST_32_MARKER, size].pack('CN>')) # Use N> for network byte order
          end

          list.each { |item| pack(item) }
        end

        def pack_integer(int)
          if int.between?(TINY_INT_MIN, TINY_INT_MAX) # Tiny Integer
            write_marker([int].pack('c')) # Signed char for range -128 to 127
          elsif int.between?(INT_8_MIN, INT_8_MAX) # INT_8
            write_marker_and_data([INT_8].pack('C'), [int].pack('c'))
          elsif int.between?(INT_16_MIN, INT_16_MAX) # INT_16
            write_marker_and_data([INT_16].pack('C'), [int].pack('s>'))
          elsif int.between?(INT_32_MIN, INT_32_MAX) # INT_32
            write_marker_and_data([INT_32].pack('C'), [int].pack('l>'))
          else # INT_64
            write_marker_and_data([INT_64].pack('C'), [int].pack('q')) # q is already network byte order
          end
        end

        def write_marker(marker_bytes)
          @io.write(marker_bytes)
        end

        def write_marker_and_data(marker_bytes, data_bytes)
          @io.write(marker_bytes)
          @io.write(data_bytes) if data_bytes && !data_bytes.empty?
        end
      end

      # Unpacks Packstream byte format into Ruby objects.
      class Unpacker
        # Marker Bytes
        NULL = 0xC0
        FALSEY = 0xC2
        TRUETHY = 0xC3
        INT_8 = 0xC8
        INT_16 = 0xC9
        INT_32 = 0xCA
        INT_64 = 0xCB
        FLOAT_64 = 0xC1 # Added Float marker

        TINY_STRING_MARKER_BASE = 0x80
        STRING_8_MARKER = 0xD0
        STRING_16_MARKER = 0xD1
        STRING_32_MARKER = 0xD2

        TINY_LIST_MARKER_BASE = 0x90
        LIST_8_MARKER = 0xD4
        LIST_16_MARKER = 0xD5
        LIST_32_MARKER = 0xD6

        TINY_MAP_MARKER_BASE = 0xA0
        MAP_8_MARKER = 0xD8
        MAP_16_MARKER = 0xD9
        MAP_32_MARKER = 0xDA

        TINY_STRUCT_MARKER_BASE = 0xB0
        STRUCT_8_MARKER = 0xDC
        STRUCT_16_MARKER = 0xDD
        STRUCT_32_MARKER = 0xDE

        MARKER_HIGH_NIBBLE_MASK = 0xF0
        MARKER_LOW_NIBBLE_MASK = 0x0F

        def initialize(io)
          @io = io
        end

        # Unpacks the next value from the stream.
        def unpack
          marker = read_byte
          unpack_value(marker)
        end

        private

        def unpack_value(marker)
          # Add logging here
          # Tiny types
          return marker if marker >= 0 && marker < TINY_STRING_MARKER_BASE # Tiny Positive Int
          return marker - 256 if marker >= 0xF0 # Tiny Negative Int (-1 to -16)

          high_nibble = marker & MARKER_HIGH_NIBBLE_MASK
          low_nibble = marker & MARKER_LOW_NIBBLE_MASK

          case high_nibble
          when TINY_STRING_MARKER_BASE then return unpack_string(low_nibble)
          when TINY_LIST_MARKER_BASE   then return unpack_list(low_nibble)
          when TINY_MAP_MARKER_BASE    then return unpack_map(low_nibble)
          when TINY_STRUCT_MARKER_BASE then return unpack_structure(low_nibble)
          end

          # Other markers
          case marker
          when NULL then nil
          when FALSEY then false
          when TRUETHY then true
          when INT_8 then read_int(1, 'c')
          when INT_16 then read_int(2, 's>')
          when INT_32 then read_int(4, 'l>')
          when INT_64 then read_int(8, 'q>')
          when STRING_8_MARKER then unpack_string(read_size(1))
          when STRING_16_MARKER then unpack_string(read_size(2))
          when STRING_32_MARKER then unpack_string(read_size(4))
          when LIST_8_MARKER then unpack_list(read_size(1))
          when LIST_16_MARKER then unpack_list(read_size(2))
          when LIST_32_MARKER then unpack_list(read_size(4))
          when MAP_8_MARKER then unpack_map(read_size(1))
          when MAP_16_MARKER then unpack_map(read_size(2))
          when MAP_32_MARKER then unpack_map(read_size(4))
          when STRUCT_8_MARKER then unpack_structure(read_size(1))
          when STRUCT_16_MARKER then unpack_structure(read_size(2))
          when STRUCT_32_MARKER then unpack_structure(read_size(4))
          when FLOAT_64 then unpack_float64
          # TODO: Add Bytes
          else
            raise ProtocolError, "Unknown Packstream marker: 0x#{marker.to_s(16)}"
          end
        end

        def unpack_string(size)
          read_bytes(size).force_encoding('UTF-8')
        end

        def unpack_list(size)
          Array.new(size) { unpack }
        end

        def unpack_map(size)
          Array.new(size) { [unpack, unpack] }.to_h # Assumes keys are strings after unpack
        end

        # Unpacks a structure into a [signature, [fields]] array
        def unpack_structure(size)
          signature = read_byte
          fields = Array.new(size) { unpack }
          [signature, fields]
        end

        def unpack_float64
          # Reads 8 bytes and unpacks as a double-precision float, big-endian
          read_bytes(8).unpack1('G')
        end

        # Helper to read a single byte as an integer
        def read_byte
          byte = @io.read(1)
          raise EOFError, 'Unexpected end of stream while reading byte' if byte.nil?

          byte.unpack1('C')
        end

        # Helper to read size markers (unsigned integers)
        # Helper to read size markers (unsigned integers)
        def read_size(num_bytes)
          bytes = read_bytes(num_bytes) # Read first
          case num_bytes
          when 1 then bytes.unpack1('C')
          when 2 then bytes.unpack1('n') # Use 'n' (network byte order = big-endian)
          when 4 then bytes.unpack1('N') # Use 'N' (network byte order = big-endian)
          else raise ArgumentError, "Invalid size length: #{num_bytes}"
          end
        end

        # Helper to read signed integers
        def read_int(num_bytes, format)
          bytes = read_bytes(num_bytes) # Read first
          # Add logging immediately before unpack
          #
          # Put '>' back as it's needed for big-endian
          bytes.unpack1(format)
        end

        # Helper to read exactly n bytes
        def read_bytes(n)
          return ''.b if n.zero? # Handle zero-length reads

          data = @io.read(n)
          # More robust check
          raise EOFError, "Unexpected end of stream while reading #{n} bytes (got #{data&.bytesize || 'nil'})" unless data && data.bytesize == n

          data
        end
      end

      # Helper function to pack a value into a string
      def self.pack(value)
        io = StringIO.new(+'', 'wb') # Binary mode important
        packer = Packer.new(io)
        packer.pack(value)
        io.string
      end

      # Helper function to unpack a value from a string
      def self.unpack(bytes)
        io = StringIO.new(bytes, 'rb') # Binary mode important
        unpacker = Unpacker.new(io)
        unpacker.unpack
      end
    end
  end
end
