# frozen_string_literal: true

require 'minitest/autorun'
require 'active_cypher/connection_pool'

# The pool must hand each thread its own connection.
#
# Bolt is a stateful, ordered protocol over one socket. Sharing an adapter
# across threads lets their reads and writes interleave, and the failure is not
# a clean error -- it is a corrupted stream:
#
#   ActiveCypher::ProtocolError: Failed to decode message:
#     FrozenError - can't modify frozen IO::Stream::StringBuffer
#
# Observed with six threads against Memgraph, plus spurious
# Memgraph.ExecutionException from replies matched to the wrong request. Any
# threaded job runner hits it: GoodJob defaults to 5 threads, Sidekiq to 10.
class ConnectionPoolThreadingTest < Minitest::Test
  # A pool whose build step is stubbed, so this tests the handing-out and not
  # the network.
  class FakeAdapter
    def active? = true
    def disconnect = nil
  end

  def pool
    p = ActiveCypher::ConnectionPool.allocate
    p.instance_variable_set(:@spec, { adapter: 'fake' })
    p.instance_variable_set(:@connections, {})
    p.instance_variable_set(:@creation_mutex, Mutex.new)
    def p.build_connection = FakeAdapter.new
    p
  end

  def test_each_thread_gets_its_own_connection
    p = pool
    conns = 8.times.map { Thread.new { p.connection } }.map(&:value)

    assert_equal 8, conns.map(&:object_id).uniq.size,
                 'threads shared a connection; the Bolt stream will corrupt'
  end

  def test_the_same_thread_reuses_its_connection
    p = pool

    assert_same p.connection, p.connection
  end

  def test_disconnect_closes_every_live_thread_s_connection
    p = pool
    gate = Queue.new
    # Threads held ALIVE, so their connections are genuinely tracked rather
    # than reaped as orphans while the test is still setting up.
    ts = 4.times.map { Thread.new { p.connection; gate.pop } }
    sleep 0.05 until p.instance_variable_get(:@connections).size == 4

    p.disconnect

    assert_empty p.instance_variable_get(:@connections)
    4.times { gate << :go }
    ts.each(&:join)
  end

  # A connection whose thread has exited must be CLOSED, not merely forgotten.
  # Otherwise a process that spawns short-lived threads leaks a Bolt socket per
  # thread, and the server counts them against max_connections.
  def test_connections_of_dead_threads_are_disconnected
    closed = []
    p = pool
    p.define_singleton_method(:build_connection) do
      a = FakeAdapter.new
      a.define_singleton_method(:disconnect) { closed << object_id }
      a
    end

    dead = Thread.new { p.connection }
    dead.join
    refute dead.alive?

    p.connection # triggers the reap

    assert_equal 1, closed.size, "the dead thread's connection was leaked"
  end
end
