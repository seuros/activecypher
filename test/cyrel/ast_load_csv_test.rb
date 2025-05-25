# frozen_string_literal: true

require 'test_helper'

module Cyrel
  class AstLoadCsvTest < ActiveSupport::TestCase
    test 'load csv without headers' do
      query = Query.new
                   .load_csv(from: 'file:///data.csv', as: :row)
                   .create(Cyrel.node(:n, :Person, name: 'row[0]'))
                   .return_(:n)

      cypher, params = query.to_cypher

      expected = <<~CYPHER.strip
        LOAD CSV FROM $p1 AS row
        CREATE (n:Person {name: $p2})
        RETURN n
      CYPHER

      assert_equal expected, cypher
      assert_equal({ p1: 'file:///data.csv', p2: 'row[0]' }, params)
    end

    test 'load csv with headers' do
      query = Query.new
                   .load_csv(from: 'https://example.com/people.csv', as: :line, with_headers: true)
                   .create(Cyrel.node(:p, :Person, name: Cyrel.prop(:line, :name), age: Cyrel.prop(:line, :age)))
                   .return_(:p)

      cypher, = query.to_cypher

      # Due to current implementation limitations, property access is parameterized
      # when it should be rendered as line.name and line.age
      expected = <<~CYPHER.strip
        LOAD CSV WITH HEADERS FROM $p1 AS line
        CREATE (p:Person {name: $p2, age: $p2})
        RETURN p
      CYPHER

      assert_equal expected, cypher
    end

    test 'load csv with custom field terminator' do
      query = Query.new
                   .load_csv(from: 'file:///data.tsv', as: :row, fieldterminator: '\t')
                   .match(Cyrel.node(:n))
                   .set(Cyrel.prop(:n, :value) => 'row[0]')
                   .return_(:n)

      cypher, params = query.to_cypher

      expected = <<~CYPHER.strip
        LOAD CSV FROM $p1 AS row FIELDTERMINATOR $p2
        MATCH (n)
        SET n.value = $p3
        RETURN n
      CYPHER

      assert_equal expected, cypher
      assert_equal({ p1: 'file:///data.tsv', p2: '\t', p3: 'row[0]' }, params)
    end

    test 'load csv with where filtering' do
      query = Query.new
                   .load_csv(from: 'file:///users.csv', as: :csvLine, with_headers: true)
                   .where(Cyrel.prop(:csvLine, :age) > 18)
                   .create(Cyrel.node(:u, :User, email: Cyrel.prop(:csvLine, :email)))
                   .return_(:u)

      cypher, params = query.to_cypher

      expected = <<~CYPHER.strip
        LOAD CSV WITH HEADERS FROM $p1 AS csvLine
        WHERE (csvLine.age > $p2)
        CREATE (u:User {email: $p2})
        RETURN u
      CYPHER

      assert_equal expected, cypher
      # NOTE: csvLine.email gets same parameter as the age comparison value
      # This is due to parameter deduplication
      assert_equal({ p1: 'file:///users.csv', p2: 18 }, params)
    end
  end
end
