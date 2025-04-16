# frozen_string_literal: true

require 'stringio'

module ActiveCypher
  module Bolt
    # Handles decoding chunked Packstream data into Bolt messages for Bolt v5.x.
    class MessageReader
      MAX_CHUNK_SIZE = 65_535 # Maximum size for a single chunk (unsigned 16-bit int)
      READ_TIMEOUT = 15 # Seconds to wait for a read operation

      def initialize(io)
        @io = io
        @buffer = StringIO.new(+'', 'rb+') # Internal buffer for chunked data
      end

      # Reads and decodes the next Bolt message from the stream.
      # Handles Bolt's chunking mechanism.
      #
      # @return [Messaging::Message] The decoded message object.
      # @raise [ProtocolError] If decoding fails or an unknown message type is received.
      # @raise [ConnectionError] If the connection is lost during reading.
      def read_message
        message_bytes = read_message_chunks
        return nil if message_bytes.nil? || message_bytes.empty?

        unpacker = Packstream::Unpacker.new(StringIO.new(message_bytes, 'rb'))
        signature, fields = unpacker.unpack

        klass = find_message_class(signature) or
          raise ProtocolError, "Unknown message signature 0x#{signature.to_s(16)}"

        klass.new(*fields)
      rescue EOFError => e
        raise ConnectionError, "Connection closed while reading message: #{e.message}"
      rescue ConnectionError
        raise
      rescue StandardError => e
        raise ProtocolError, "Failed to decode message: #{e.class} - #{e.message}"
      end

      private

      def read_raw_from_io(n)
        Async::Task.current.with_timeout(READ_TIMEOUT) do
          data = @io.read_exactly(n)
          raise EOFError, 'Connection closed during read' unless data

          return data
        end
      rescue Async::TimeoutError
        raise ConnectionError, "Read operation timed out after #{READ_TIMEOUT}s"
      rescue Errno::ECONNRESET, Errno::EPIPE, IOError, EOFError => e
        raise ConnectionError, "Connection lost: #{e.message}"
      end

      # Reads message chunks from the IO stream until a zero chunk is found.
      # @return [String] The concatenated bytes of the message.
      def read_message_chunks
        @buffer.rewind
        @buffer.truncate(0)

        loop do
          chunk_size_bytes = read_raw_from_io(2)
          chunk_size       = chunk_size_bytes.unpack1('n')

          break if chunk_size.zero?
          raise ProtocolError, "Chunk too large (#{chunk_size})" if chunk_size > MAX_CHUNK_SIZE

          @buffer.write(read_raw_from_io(chunk_size))
        end

        @buffer.string
      end

      # Finds the message class corresponding to a signature byte.
      def find_message_class(signature)
        case signature
        when Messaging::Success::SIGNATURE then Messaging::Success
        when Messaging::Failure::SIGNATURE then Messaging::Failure
        when Messaging::Ignored::SIGNATURE then Messaging::Ignored
        when Messaging::Hello::SIGNATURE   then Messaging::Hello # Technically shouldn't receive HELLO, its old stuff
        when Messaging::Run::SIGNATURE     then Messaging::Run   # Shouldn't receive RUN either
        when Messaging::Pull::SIGNATURE    then Messaging::Pull  # Shouldn't receive PULL
        when Messaging::Discard::SIGNATURE then Messaging::Discard # Shouldn't receive DISCARD
        when Messaging::Record::SIGNATURE  then Messaging::Record
        when Messaging::Begin::SIGNATURE   then Messaging::Begin   # Shouldn't receive BEGIN
        when Messaging::Commit::SIGNATURE  then Messaging::Commit  # Shouldn't receive COMMIT
        when Messaging::Rollback::SIGNATURE then Messaging::Rollback # Shouldn't receive ROLLBACK
        when Messaging::Goodbye::SIGNATURE then Messaging::Goodbye
        when Messaging::Logon::SIGNATURE then Messaging::Logon
        when Messaging::Logoff::SIGNATURE then Messaging::Logoff
        when Messaging::Route::SIGNATURE then Messaging::Route
        when Messaging::Reset::SIGNATURE then Messaging::Reset
        when Messaging::Telemetry::SIGNATURE then Messaging::Telemetry
        end
      end
    end
  end
end
