# frozen_string_literal: true

module ActiveCypher
  module Bolt
    # Handles encoding Bolt messages into Packstream format for Bolt v5.0
    class MessageWriter
      # Structure Markers
      TINY_STRUCT_MARKER_BASE = 0xB0
      STRUCT_8_MARKER = 0xDC
      STRUCT_16_MARKER = 0xDD
      # STRUCT_32_MARKER = 0xDE # Not implementing 32-bit sizes for now

      def initialize(io)
        @packer = Packstream::Packer.new(io)
        @io = io # Keep a reference for direct writing if needed
      end

      # Encodes and writes a Bolt message to the underlying IO stream.
      # @param message [Messaging::Message] The message object to write.
      def write(message)
        # Bolt 4.3 requires different chunking
        size = message.fields.size

        # Write structure header with size and signature
        if size < 16
          write_marker([TINY_STRUCT_MARKER_BASE | size].pack('C'))
        else
          write_marker([STRUCT_8_MARKER, size].pack('CC'))
        end

        # Write signature
        write_marker([message.signature].pack('C'))

        # Pack fields with careful handling of nils
        message.fields.each do |field|
          if field.nil?
            @packer.pack(nil)
          else
            @packer.pack(field)
          end
        end
      end

      private

      # Method removed as it's not used anymore - we're using the new write method above

      def write_marker(marker_bytes)
        @io.write(marker_bytes)
      end
    end
  end
end
