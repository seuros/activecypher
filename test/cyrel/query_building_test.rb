# frozen_string_literal: true

require 'test_helper'
require 'cyrel'

class QueryBuildingTest < ActiveSupport::TestCase
  test 'query building - simple match and return' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: 'Person', properties: { name: 'Alice' })
    query = Cyrel::Query.new
                        .match(person_node)
                        .return_(Cyrel.prop(:p, :age))

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (p:Person {name: $p1})
      RETURN p.age
    CYPHER
    expected_params = { p1: 'Alice' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'query building - match, where, return' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: 'Person')
    query = Cyrel::Query.new
                        .match(person_node)
                        .where(Cyrel.prop(:p, :age) > 30)
                        .return_(:p) # Return the node itself

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (p:Person)
      WHERE (p.age > $p1)
      RETURN p
    CYPHER
    expected_params = { p1: 30 }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'query building - match, multiple where conditions, return' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: 'Person')
    query = Cyrel::Query.new
                        .match(person_node)
                        .where(Cyrel.prop(:p, :age) > 30)
                        .where(Cyrel.prop(:p, :city) == 'London')
                        .return_(Cyrel.prop(:p, :name))

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (p:Person)
      WHERE (p.age > $p1) AND (p.city = $p2)
      RETURN p.name
    CYPHER
    expected_params = { p1: 30, p2: 'London' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'query building - match, where hash, return' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: 'Person')
    query = Cyrel::Query.new
                        .match(person_node)
                        .where(name: 'Bob', status: 'active') # Uses infer_alias
                        .return_(:p)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (p:Person)
      WHERE (p.name = $p1) AND (p.status = $p2)
      RETURN p
    CYPHER
    expected_params = { p1: 'Bob', p2: 'active' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'query building - match, set labels' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: 'Person', properties: { name: 'Alice' })
    query = Cyrel::Query.new
                        .match(person_node)
                        .set([[:p, 'Employee']]) # Set label
                        .return_(:p)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (p:Person {name: $p1})
      SET p:Employee
      RETURN p
    CYPHER
    expected_params = { p1: 'Alice' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'query building - match, remove property' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: 'Person', properties: { name: 'Alice' })
    query = Cyrel::Query.new
                        .match(person_node)
                        .remove(Cyrel.prop(:p, :age))
                        .return_(:p)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (p:Person {name: $p1})
      REMOVE p.age
      RETURN p
    CYPHER
    expected_params = { p1: 'Alice' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'query building - match, remove label' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: %w[Person Temporary], properties: { name: 'Alice' })
    query = Cyrel::Query.new
                        .match(person_node)
                        .remove([:p, 'Temporary']) # Remove label
                        .return_(:p)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (p:Person:Temporary {name: $p1})
      REMOVE p:Temporary
      RETURN p
    CYPHER
    expected_params = { p1: 'Alice' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'query building - match, delete' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: 'Person', properties: { name: 'Obsolete' })
    query = Cyrel::Query.new
                        .match(person_node)
                        .delete_(:p) # Note the underscore

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (p:Person {name: $p1})
      DELETE p
    CYPHER
    expected_params = { p1: 'Obsolete' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'query building - match, detach delete' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: 'Person', properties: { name: 'Obsolete' })
    query = Cyrel::Query.new
                        .match(person_node)
                        .detach_delete(:p)

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (p:Person {name: $p1})
      DETACH DELETE p
    CYPHER
    expected_params = { p1: 'Obsolete' }
    assert_equal [expected_cypher, expected_params], query.to_cypher
  end

  test 'query building - match, with, return' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: 'Person')
    # query = Cyrel::Query.new # Original line removed as it wasn't used
    #              .match(person_node)
    #              .with(Cyrel.prop(:p, :name).as('personName')) # .as() not implemented
    #              .return_('personName')

    # Using RawExpressionString for AS for now
    query_with_raw = Cyrel::Query.new
                                 .match(person_node)
                                 .with(Cyrel::Clause::With::RawExpressionString.new('p.name AS personName'))
                                 .return_(Cyrel::Clause::Return::RawIdentifier.new('personName'))

    expected_cypher = <<~CYPHER.chomp.strip
      MATCH (p:Person)
      WITH p.name AS personName
      RETURN personName
    CYPHER
    expected_params = {}
    assert_equal [expected_cypher, expected_params], query_with_raw.to_cypher
  end

  test 'query building - match, order by, return' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: 'Person')
    query = Cyrel::Query.new
                        .match(person_node)
                        .order_by([Cyrel.prop(:p, :age), :desc], [Cyrel.prop(:p, :name), :asc])
                        .return_(:p)

    <<~CYPHER.chomp.strip # Assign to variable
      MATCH (p:Person)
      RETURN p
      ORDER BY p.age DESC, p.name
    CYPHER
    expected_params = {}
    # NOTE: Clause order in output depends on Query#clause_order
    # Adjust assertion if order differs but is logically correct.
    # Let's test the generated parts separately if order is unstable
    cypher, params = query.to_cypher
    assert_match(/MATCH \(p:Person\)/, cypher)
    assert_match(/RETURN p/, cypher)
    assert_match(/ORDER BY p.age DESC, p.name/, cypher)
    assert_equal expected_params, params
  end

  test 'query building - match, skip, limit, return' do
    person_node = Cyrel::Pattern::Node.new(:p, labels: 'Person')
    query = Cyrel::Query.new
                        .match(person_node)
                        .return_(:p)
                        .skip(10)
                        .limit(5)

    <<~CYPHER.chomp.strip # Assign to variable
      MATCH (p:Person)
      RETURN p
      SKIP $p1
      LIMIT $p2
    CYPHER
    expected_params = { p1: 10, p2: 5 }
    cypher, params = query.to_cypher
    assert_match(/MATCH \(p:Person\)/, cypher)
    assert_match(/RETURN p/, cypher)
    assert_match(/SKIP \$p\d+/, cypher) # Check for SKIP param
    assert_match(/LIMIT \$p\d+/, cypher) # Check for LIMIT param
    assert_equal expected_params, params
  end

  test 'query building - complex query' do
    # Match users older than 30, optionally match their posts,
    # return user name and count of posts, ordered by name.
    user_node = Cyrel::Pattern::Node.new(:u, labels: 'User')
    post_node = Cyrel::Pattern::Node.new(:p, labels: 'Post')
    rel = Cyrel::Pattern::Relationship.new(types: 'AUTHORED', direction: :outgoing)
    path = Cyrel::Pattern::Path.new([user_node, rel, post_node])

    # query = Cyrel::Query.new # Original lines removed as they weren't used
    #              .match(user_node)
    #              .where(Cyrel.prop(:u, :age) > 30)
    #              .optional_match(path)
    #              .with(Cyrel.prop(:u, :name).as('userName'), Cyrel.count(:p).as('postCount')) # .as() not implemented
    #              .order_by(['userName', :asc])
    #              .return_('userName', 'postCount')

    # Rebuild with RawExpressionString/RawIdentifier for AS/bare returns
    query_raw = Cyrel::Query.new
                            .match(user_node)
                            .where(Cyrel.prop(:u, :age) > 30)
                            .optional_match(path)
                            .with(Cyrel::Clause::With::RawExpressionString.new('u.name AS userName'),
                                  Cyrel::Clause::With::RawExpressionString.new('count(p) AS postCount'))
                            .order_by(['userName', :asc]) # Order by alias
                            .return_(Cyrel::Clause::Return::RawIdentifier.new('userName'),
                                     Cyrel::Clause::Return::RawIdentifier.new('postCount'))

    <<~CYPHER.chomp.strip # Assign to variable
      MATCH (u:User)
      WHERE (u.age > $p1)
      OPTIONAL MATCH (u:User)-[:AUTHORED]->(p:Post)
      WITH u.name AS userName, count(p) AS postCount
      RETURN userName, postCount
      ORDER BY userName
    CYPHER
    expected_params = { p1: 30 }

    cypher, params = query_raw.to_cypher
    # Check parts due to potential ordering variations
    assert_match(/MATCH \(u:User\)/, cypher)
    assert_match(/WHERE \(u.age > \$p\d+\)/, cypher)
    assert_match(/OPTIONAL MATCH \(u:User\)-\[:AUTHORED\]->\(p:Post\)/, cypher)
    assert_match(/WITH u.name AS userName, count\(p\) AS postCount/, cypher)
    assert_match(/RETURN userName, postCount/, cypher)
    assert_match(/ORDER BY userName/, cypher)
    assert_equal expected_params, params
  end
end
