# frozen_string_literal: true

module ActiveCypher
  module Bolt
    module VersionEncoding
      private

      # ----------------------------
      # Encode: [0,0,minor,major]
      # ----------------------------
      # Accepts Float (5.8), String ('5.8'), Integer (5) or [major,minor]
      def encode_version(ver)
        major, minor =
          case ver
          when Float   then [ver.to_i, (ver * 10).round % 10]
          when String  then ver.split('.').map(&:to_i)
          when Integer then [ver, 0]
          when Array   then ver
          else
            raise ArgumentError, "Unsupported version #{ver.inspect}"
          end

        [0, 0, minor, major].pack('C4')
      end

      # ----------------------------
      # Decode: extract minor / major
      # ----------------------------
      def decode_version(bytes)
        raise ArgumentError, 'need 4 bytes' unless bytes.bytesize == 4

        minor = bytes.getbyte(2)
        major = bytes.getbyte(3)

        return 0.0 if major.zero? && minor.zero?

        "#{major}.#{minor}".to_f # or return [major, minor]
      end
    end
  end
end
