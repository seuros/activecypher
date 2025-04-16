# ActiveCypher

ActiveCypher is a Ruby gem that provides an ActiveRecord-like interface for interacting with graph databases using the OpenCypher query language. It aims to simplify graph database operations within Ruby and Ruby on Rails applications by leveraging familiar patterns from ActiveModel.

The core of ActiveCypher includes:

*   **Cyrel:** A powerful Domain Specific Language (DSL) for building Cypher queries programmatically in Ruby.
*   **ActiveModel Integration:** Leverages ActiveModel conventions for a familiar development experience.
*   **Rails Engine:** Seamlessly integrates into Ruby on Rails applications.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activecypher'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install activecypher
```

## Configuration

To configure ActiveCypher, create an initializer file in your Rails application (e.g., `config/initializers/active_cypher.rb`) and specify the connection details for your graph database. ActiveCypher provides built-in adapters for Neo4j and Memgraph using the Bolt protocol.

Example configuration for Neo4j:

```ruby
# config/initializers/active_cypher.rb

ActiveCypher.configure do |config|
  config.adapter = ActiveCypher::ConnectionAdapters::Neo4jAdapter.new(
    uri: "bolt://localhost:7687",
    username: "neo4j",
    password: "your_password"
  )
end
```

Example configuration for Memgraph:

```ruby
# config/initializers/active_cypher.rb

ActiveCypher.configure do |config|
  config.adapter = ActiveCypher::ConnectionAdapters::MemgraphAdapter.new(
    uri: "bolt://localhost:7688",
    username: "memgraph",
    password: "your_password"
  )
end
```

Refer to the test files (e.g., `test/bolt/connection_test.rb` and `test/bolt/session_test.rb`) for more usage examples.

## Usage

ActiveCypher allows you to define models representing nodes and relationships in your graph, using Ruby classes. See below for real examples from [`test/dummy/app/graph`](test/dummy/app/graph):

**Example: Defining Node and Relationship Models**

```ruby
# app/graph/person_node.rb
class PersonNode < ApplicationGraphNode
  attribute :id, :string
  attribute :name, :string
  attribute :age, :integer
  attribute :active, :boolean, default: true
  attribute :internal_id, :string

  validates :name, presence: true
end

# app/graph/conspiracy_node.rb
class ConspiracyNode < ApplicationGraphNode
  attribute :name,         :string
  attribute :description,  :string
  attribute :believability_index, :integer

  has_many :followers,
           class_name: 'PersonNode',
           relationship: 'BELIEVES_IN',
           direction: :in,
           relationship_class: 'BelievesInRelationship'
end

# app/graph/believes_in_relationship.rb
class BelievesInRelationship < ApplicationGraphRelationship
  from_class 'PersonNode'
  to_class   'ConspiracyNode'
  type       'BELIEVES_IN'

  attribute :reddit_karma_spent, :integer
  attribute :level_of_devotion,  :string # "casual", "zealot", "makes merch"
end
```

**Example: Creating and Querying Nodes and Relationships**

```ruby
# Create a new person node
person = PersonNode.create(name: 'Alice', age: 30)

# Create a new conspiracy node
conspiracy = ConspiracyNode.create(name: 'Flat Earth', description: 'The earth is flat.', believability_index: 1)

# Create a relationship between person and conspiracy
BelievesInRelationship.create(
  from: person,
  to: conspiracy,
  reddit_karma_spent: 100,
  level_of_devotion: 'casual'
)

# Find all people who believe in a specific conspiracy
followers = conspiracy.followers

# Find all conspiracies a person believes in
conspiracies = person.believes_in_relationships.map(&:to)
```

**Example: Querying with Cyrel**

```ruby
# Find all people named 'Alice'
people = PersonNode.where(name: 'Alice')

# Find all conspiracies with a believability index greater than 5
believable_conspiracies = ConspiracyNode.where('believability_index > ?', 5)
```

*(See more detailed usage and advanced queries in the models and test files in `test/dummy/app/graph`.)*

## Features

*   **Cyrel DSL:** Intuitive Ruby DSL for constructing complex Cypher queries ([see detailed Cyrel documentation](./CYREL.md)).
*   **ActiveRecord-like Patterns:** Familiar interface for developers accustomed to ActiveRecord.
*   **Rails Integration:** Easy integration into Rails projects via Rails Engine.
*   **Comprehensive Cypher Support:** Aims to support a wide range of Cypher clauses and functions (refer to [`CYREL.md`](./CYREL.md) and `test/cyrel/` for examples).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `lib/active_cypher/version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/seuros/activecypher. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActiveCypher project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/seuros/activecypher/blob/master/CODE_OF_CONDUCT.md). *(Note: The CODE_OF_CONDUCT.md file might need to be created)*
