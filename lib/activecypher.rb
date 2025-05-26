# frozen_string_literal: true

require 'active_support'
require 'zeitwerk'
require_relative 'cyrel'
require_relative 'active_cypher/version'
require_relative 'active_cypher/redaction'

# ActiveCypher is a Ruby gem that provides an ActiveRecord-like interface for
# interacting with Neo4j databases using Cypher queries.

module ActiveCypher
  # Base error class. Rescue this if you're ready to admit something went wrong,
  # but you're too emotionally unavailable to care what exactly it was.
  class Error < StandardError; end
  # For when you configured something wrong.
  # A gentle reminder that "boot time" is also "blame time."
  class ConfigurationError < Error; end

  # You tried to use an adapter that doesn’t exist.
  # It's not ghosting if it was never real to begin with.
  class AdapterNotFoundError < ConfigurationError; end

  # You found the adapter, but loading it failed.
  # Like plugging in a toaster and discovering it's full of bees.
  class AdapterLoadError < ConfigurationError; end

  # You specified an environment that only exists in your imagination.
  # Not everyone gets to be 'production', Brad.
  class UnknownEnvironmentError < ConfigurationError; end

  # The connection string is a lie.
  # It promised connectivity. It delivered chaos.
  class UnknownConnectionError < ConfigurationError; end

  # Something went wrong in the connection layer.
  # Possibly sabotage. Possibly just your code.
  class ConnectionError < Error; end

  # You never established a connection, and yet here you are—
  # trying to ask the database for stuff like it owes you rent.
  class ConnectionNotEstablished < ConnectionError; end

  # The connection timed out. The database waited. It hoped. It gave up.
  class ConnectionTimeoutError < ConnectionError; end

  # The protocol is broken. Not socially — technically.
  # Although, honestly, maybe both.
  class ProtocolError < ConnectionError; end

  # Something exploded during a query.
  # Could be you. Could be Cypher. Could be fate.
  class QueryError < Error; end

  # Your Cypher syntax is... interpretive.
  # Unfortunately, the parser isn’t in the mood for interpretive dance.
  class CypherSyntaxError < QueryError; end

  # The record you tried to find doesn’t exist.
  # It heard you were coming and left.
  class RecordNotFound < QueryError; end

  # Your transaction failed to commit.
  # So did your hopes and dreams.
  class TransactionError < QueryError; end

  # Persistence went wrong.
  # The data tried to stay, but it just couldn't handle the pressure.
  class PersistenceError < Error; end

  # You tried to save a record, but it ghosted you mid-write.
  class RecordNotSaved < PersistenceError; end

  # You tried to destroy a record, but it clung to life.
  # Congratulations. You discovered data with survival instincts.
  class RecordNotDestroyed < PersistenceError; end

  # Something failed validation.
  # Probably your logic. Possibly your entire existence.
  class ValidationError < PersistenceError; end

  # You tried to instantiate an abstract class.
  # That’s not just bad practice—it’s metaphysically wrong.
  class AbstractClassError < PersistenceError; end

  # Something went wrong with an association.
  # Relationships are hard—even for nodes.
  class AssociationError < Error; end

  # You associated two things that really shouldn’t be talking.
  # Stop trying to make fetch happen.
  class AssociationTypeMismatch < AssociationError; end

  # You messed up a has_many :through.
  # Welcome to the Bermuda Triangle of ORM logic.
  class HasManyThroughError < AssociationError; end
end

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/active_cypher/version.rb")
loader.ignore("#{__dir__}/active_cypher/railtie.rb")
loader.ignore("#{__dir__}/active_cypher/generators")
loader.ignore("#{__dir__}/activecypher.rb")
loader.ignore("#{__dir__}/cyrel.rb")
loader.inflector.inflect(
  'activecypher' => 'ActiveCypher',
  'dsl_context' => 'DSLContext',
  'ast' => 'AST'
)

loader.push_dir("#{__dir__}/cyrel", namespace: Cyrel)
loader.setup

require 'active_cypher/railtie' if defined?(Rails)
