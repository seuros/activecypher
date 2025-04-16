# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/hash/indifferent_access'

module ActiveCypher
  module Bolt
    # @!parse
    #   # Messaging: Because every protocol needs a registry, and every registry needs a protocol.
    module Messaging
      # Internal registry: signature byte → Message subclass
      @registry = {}

      class << self
        # For introspection
        def registry
          @registry.dup
        end

        # Lookup-and-instantiate based on signature + raw fields
        #
        # @param signature [Integer] the Bolt message signature
        # @param fields    [Array]   the decoded fields for this message
        # @return [Message] instance of the right subclass, or generic Message
        def for_signature(signature, *fields)
          if (klass = @registry[signature])
            klass.new(*fields)
          else
            Message.new(signature, fields)
          end
        end

        # Register a subclass if it defines SIGNATURE
        def register(subclass)
          return unless subclass.const_defined?(:SIGNATURE)

          sig = subclass.const_get(:SIGNATURE)
          @registry[sig] = subclass
        end

        # Normalize any metadata or parameters map
        def normalize_map(map)
          (map || {}).with_indifferent_access
        end
      end

      # Base class — automatically registers subclasses with SIGNATURE
      # Because inheritance hierarchies are the only thing deeper than this protocol.
      class Message
        attr_reader :signature, :fields

        def initialize(signature, fields)
          @signature = signature
          @fields    = fields
        end

        def ==(other)
          other.class == self.class &&
            other.signature == signature &&
            other.fields    == fields
        end
        alias eql? ==

        def self.inherited(subclass)
          Messaging.register(subclass)
          super
        end
      end

      # The HELLO message. Because every protocol needs to start with a greeting before the disappointment.
      class Hello < Message
        SIGNATURE = 0x01

        def initialize(metadata)
          meta = Messaging.normalize_map(metadata)
          super(SIGNATURE, [meta])
        end

        def metadata
          fields.first
        end
      end

      # The GOODBYE message. For when you've had enough of this session, or life.
      class Goodbye < Message
        SIGNATURE = 0x02

        def initialize
          super(SIGNATURE, [])
        end
      end

      # The RESET message. Because sometimes you just want to pretend nothing ever happened.
      class Reset < Message
        SIGNATURE = 0x0F

        def initialize
          super(SIGNATURE, [])
        end
      end

      # The RUN message. Because what else would you do with a database connection?
      class Run < Message
        SIGNATURE = 0x10

        # metadata may include bookmarks, tx_timeout, tx_metadata, mode, db
        def initialize(query, parameters, metadata = {})
          meta = Messaging.normalize_map(metadata)
          params = Messaging.normalize_map(parameters)

          # Neo4j mode normalization: single-char 'r' or 'w'
          meta['mode'] = meta['mode'][0] if meta['mode'].is_a?(String) && meta['mode'].length > 1

          super(SIGNATURE, [query, params, meta])
        end

        def query      = fields[0]
        def parameters = fields[1]
        def metadata   = fields[2]
      end

      # The BEGIN message. Because transactions are just promises waiting to be broken.
      class Begin < Message
        SIGNATURE = 0x11

        # metadata may include mode, db, tx_metadata, etc.
        def initialize(metadata = {})
          meta = Messaging.normalize_map(metadata)

          # Never set db to neo4j for memgraph
          if meta['adapter'] == 'memgraph'
            # For Memgraph, remove db key entirely if present
            meta.delete('db')
          elsif meta['mode'].is_a?(String) && meta['mode'].length == 1
            # This is for Neo4j only
            meta['db'] ||= 'neo4j'
          end

          # Set default mode if not present
          meta['mode'] ||= 'write'

          super(SIGNATURE, [meta])
        end

        def metadata
          fields.first
        end
      end

      # The COMMIT message. For when you want to pretend your changes are permanent.
      class Commit < Message
        SIGNATURE = 0x12

        def initialize
          super(SIGNATURE, [])
        end
      end

      # The ROLLBACK message. Because sometimes you just want to undo your mistakes.
      class Rollback < Message
        SIGNATURE = 0x13

        def initialize
          super(SIGNATURE, [])
        end
      end

      # The DISCARD message. For when you want to throw away results, or your hopes.
      class Discard < Message
        SIGNATURE = 0x2F

        # metadata: { n: <N>, qid: <QID> }, where n = -1 means all
        def initialize(metadata)
          meta = Messaging.normalize_map(metadata)
          super(SIGNATURE, [meta])
        end

        def metadata = fields.first
        def n        = metadata[:n] || metadata['n']
        def qid      = metadata[:qid] || metadata['qid']
      end

      # The PULL message. Because sometimes you just want to see what you got.
      class Pull < Message
        SIGNATURE = 0x3F

        def initialize(metadata)
          meta = Messaging.normalize_map(metadata)
          super(SIGNATURE, [meta])
        end

        def metadata
          fields.first
        end
      end

      # The ROUTE message. For when you want to pretend you have control over routing.
      class Route < Message
        SIGNATURE = 0x66

        def initialize(metadata)
          meta = Messaging.normalize_map(metadata)
          super(SIGNATURE, [meta])
        end

        def metadata
          fields.first
        end
      end

      # The LOGON message. Because authentication is just another chance to be rejected.
      class Logon < Message
        SIGNATURE = 0x6A

        def initialize(metadata)
          meta = Messaging.normalize_map(metadata)
          super(SIGNATURE, [meta])
        end

        def metadata
          fields.first
        end
      end

      # The LOGOFF message. For when you want to leave quietly, without making a scene.
      class Logoff < Message
        SIGNATURE = 0x6B

        def initialize
          super(SIGNATURE, [])
        end
      end

      # The TELEMETRY message. Because someone, somewhere, cares about your metrics. Probably.
      class Telemetry < Message
        SIGNATURE = 0x54

        def initialize(metadata)
          meta = Messaging.normalize_map(metadata)
          super(SIGNATURE, [meta])
        end

        def metadata
          fields.first
        end
      end

      # The SUCCESS message. The rarest of all Bolt messages.
      class Success < Message
        SIGNATURE = 0x70

        def initialize(metadata)
          meta = Messaging.normalize_map(metadata)
          super(SIGNATURE, [meta])
        end

        def metadata
          fields.first
        end
      end

      # The RECORD message. For when you actually get data back, against all odds.
      class Record < Message
        SIGNATURE = 0x71

        def initialize(values)
          super(SIGNATURE, [values])
        end

        def values
          fields.first
        end
      end

      # The IGNORED message. For when the server just can't be bothered.
      class Ignored < Message
        SIGNATURE = 0x7E

        def initialize
          super(SIGNATURE, [])
        end
      end

      # The FAILURE message. The most honest message in the protocol.
      class Failure < Message
        SIGNATURE = 0x7F

        def initialize(metadata)
          meta = Messaging.normalize_map(metadata)
          super(SIGNATURE, [meta])
        end

        def metadata
          fields.first
        end

        def code
          metadata['code']
        end

        def message
          metadata['message']
        end
      end
    end
  end
end
