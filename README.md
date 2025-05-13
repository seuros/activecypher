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

**No manual initialization required!**

ActiveCypher automatically loads your database configuration from `config/cypher_databases.yml` (similar to how Rails uses `database.yml`). You do **not** need to manually initialize or configure adapters in an initializer.

To configure your graph database connections, simply run the install generator:

```bash
bin/rails generate active_cypher:install
```

This will create a `config/cypher_databases.yml` file in your Rails application. You can then define connections for different environments and roles. For example:

```yaml
# config/cypher_databases.yml

development:
  primary:
    url: memgraph://memgraph:activecypher@localhost:7688
    multi_db: false
  neo4j:
    url: neo4j://neo4j:activecypher@localhost:7687
    multi_db: false

test:
  primary:
    url: memgraph://memgraph:activecypher@localhost:7688
    multi_db: false
  neo4j:
    url: neo4j://neo4j:activecypher@localhost:7687
    multi_db: false

production:
  primary:
    url: memgraph+ssl://user:pass@memgraph:7687
    multi_db: false
```

ActiveCypher will automatically pick up the correct configuration for the current Rails environment.

**You do not need to call any setup code in your test helper or application initializer.**  
Connections are managed automatically, just like ActiveRecord.

### Connecting Models to Different Databases

You can configure each node (model) class to use a specific connection by using the `connects_to` class method. This allows you to route different models to different databases or roles.

For example:

```ruby
# app/graph/application_graph_node.rb
class ApplicationGraphNode < ActiveCypher::Base
  self.abstract_class = true

  connects_to writing: :primary,
              reading: :primary
end

# app/graph/neo4j_record.rb
class Neo4jRecord < ActiveCypher::Base
  self.abstract_class = true

  connects_to writing: :neo4j,
              reading: :neo4j
end
```

- All models inheriting from `ApplicationGraphNode` will use the `primary` connection (e.g., Memgraph).
- Models inheriting from `Neo4jRecord` will use the `neo4j` connection.

This makes it easy to work with multiple databases in the same application, and to direct reads/writes as needed.

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
           relationship_class: 'BelievesInRel'
end

# app/graph/believes_in_rel.rb
class BelievesInRel < ApplicationGraphRelationship
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

## Generators and Naming Conventions

ActiveCypher provides Rails generators for quickly scaffolding node and relationship classes with consistent naming conventions.

### Node Generator

By default, node classes are suffixed with `Node`. For example:

```bash
bin/rails generate active_cypher:node Person
```

Generates:

- `app/graph/person_node.rb`
- Class: `PersonNode < ApplicationGraphNode`

If you specify a name that already ends with `Node`, the generator will not double the suffix.

You can customize the suffix with `--suffix=CustomSuffix`.

### Relationship Generator

By default, relationship classes are suffixed with `Rel`. For example:

```bash
bin/rails generate active_cypher:relationship BelievesIn --from=PersonNode --to=ConspiracyNode
```

Generates:

- `app/graph/believes_in_rel.rb`
- Class: `BelievesInRel < ApplicationGraphRelationship`

If you specify a name that already ends with `Rel`, the generator will not double the suffix.

You can customize the suffix with `--suffix=CustomSuffix`.

---

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
