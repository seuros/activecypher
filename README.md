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
  neo4j:
    url: <%= ENV.fetch('NEO4J_URL', 'neo4j://neo4j:activecypher@localhost:7687') %>
    migrations_paths: graphdb/neo4j

test:
  primary:
    url: memgraph://memgraph:activecypher@localhost:7688
  neo4j:
    url: <%= ENV.fetch('NEO4J_URL', 'neo4j://neo4j:activecypher@localhost:7687') %>
    migrations_paths: graphdb/neo4j

production:
  primary:
    url: memgraph+ssc://user:pass@memgraph:7687
```

ActiveCypher will automatically pick up the correct configuration for the current Rails environment.

**You do not need to call any setup code in your test helper or application initializer.**
Connections are managed automatically, just like ActiveRecord.

### Environment Variable Configuration

Similar to ActiveRecord's `DATABASE_URL`, ActiveCypher supports the `GRAPHDB_URL` environment variable as a standard way to configure your primary graph database connection. The adapter type is automatically detected from the URL scheme:

- `neo4j://` or `neo4j+s://` → Neo4j adapter
- `memgraph://` or `memgraph+ssl://` → Memgraph adapter

Example:
```bash
# For Neo4j
export GRAPHDB_URL="neo4j://username:password@localhost:7687/database_name"

# For Memgraph
export GRAPHDB_URL="memgraph://username:password@localhost:7688"
```

When `GRAPHDB_URL` is set, it takes precedence over the corresponding entry in `cypher_databases.yml` for the primary connection.

### Connecting Models to Different Databases

You can configure each node (model) class to use a specific connection by using the `connects_to` class method. This allows you to route different models to different databases or roles.

There are two syntaxes for `connects_to`:

- **Full mapping** (separate writing/reading roles):

```ruby
class ApplicationGraphNode < ActiveCypher::Base
  self.abstract_class = true

  connects_to writing: :primary,
              reading: :primary
end
```

- **Shorthand** (same key for both roles):

```ruby
class Neo4jRecord < ActiveCypher::Base
  self.abstract_class = true

  # Equivalent to writing: :neo4j, reading: :neo4j
  connects_to :neo4j
end
```

- All models inheriting from `ApplicationGraphNode` will use the `primary` connection (e.g., Memgraph).
- Models inheriting from `Neo4jRecord` (or using `connects_to :neo4j`) will use the `neo4j` connection.

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

### Relationship Base and Node Base Convention (a.k.a. “Let’s Not Repeat Ourselves, Please”)

ActiveCypher is here to save you from yourself (and your future self at 3am). When you define an abstract relationship base class—say, `ApplicationGraphRelationship`—ActiveCypher will, by convention, automatically pair it up with the corresponding abstract node base class (like `ApplicationGraphNode`). It’s like Tinder for your base classes, but with less ghosting and more database connections.

- If your relationship base class is named `XxxRelationship`, and you have a node base class named `XxxNode` in the same namespace, ActiveCypher will ship them together faster than your favorite fandom.
- You do **not** need to manually configure this association in most cases. Go ahead, be lazy. We encourage it.

For example:

```ruby
# app/graph/application_graph_node.rb
class ApplicationGraphNode < ActiveCypher::Base
  self.abstract_class = true
  connects_to writing: :primary, reading: :primary
end

# app/graph/application_graph_relationship.rb
class ApplicationGraphRelationship < ActiveCypher::Relationship
  self.abstract_class = true
  # No need to specify node_base_class; ActiveCypher will play matchmaker and default to ApplicationGraphNode
end
```

If you’re a control freak (or just like to break the rules), you can explicitly set the node base class in your relationship base using:

```ruby
class MyRelationshipBase < ActiveCypher::Relationship
  self.abstract_class = true
  node_base_class MyNodeBase
end
```

This ensures all relationships inheriting from your abstract relationship base will always use the correct connection, and—just like your favorite coffee shop’s WiFi—cannot be overridden by random subclasses.

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

#### Adding Attributes

You can pass attributes as `name:type` arguments, just like Rails generators:

```bash
bin/rails generate active_cypher:node Planet name:string mass:float
```

This generates a node class with `attribute :name, :string` and `attribute :mass, :float`.

#### Adding Labels

You can specify Cypher labels with the `--labels` option (comma-separated):

```bash
bin/rails generate active_cypher:node SpaceStation --labels=Orbital,Habitat
```

This will add `label :Orbital` and `label :Habitat` to the generated class.

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

## ActiveCypher GraphDB Migrations

ActiveCypher ships with a lightweight migration system for managing indexes and
constraints in your graph databases. By default, migration files live under
`graphdb/migrate` for database-agnostic changes, with optional DB-specific
folders like `graphdb/neo4j`.

### Configuring Migration Paths

You can customize the locations of migration files by configuring multiple `migrations_paths` entries. This is useful if you want to organize migrations by adapter or other criteria. Use YAML array syntax in your configuration file (e.g., `config/graphdb.yml`):

```yaml
migrations_paths:
  - graphdb/migrate
  - graphdb/neo4j
  - custom_migrations/adapter_specific
Create the migration tracking constraint once:

```cypher
CREATE CONSTRAINT graph_schema_migration IF NOT EXISTS
FOR (m:SchemaMigration)
REQUIRE m.version IS UNIQUE;
```

Write migrations using the small DSL:

```ruby
class AddFacilityIndexes < ActiveCypher::Migration
  up do
    create_uniqueness_constraint :Facility, :commonid,
      name: :facility_commonid_unique

    create_node_index :Facility, :country_id, :kind,
      name: :facility_country_kind_idx

    create_rel_index :FACILITY_REL, :rel_type,
      name: :facility_rel_type_idx

    execute <<~CYPHER
      CREATE INDEX IF NOT EXISTS FOR (f:Facility) ON (f.created_at)
    CYPHER
  end
end
```

Run pending migrations with:

```bash
bin/rails graphdb:migrate
bin/rails graphdb:status
```

Migrations are append-only and should not be modified once created.

## Database Setup and Direct Access

For setting up Neo4j and Memgraph databases and direct command-line access, see [GRAPH_REFERENCE.md](GRAPH_REFERENCE.md).

### Sanity Check

Run `bin/sanity` to verify that Memgraph and Neo4j servers are reachable on
ports 7688 and 7687. The script exits with an error if either service is not
listening.


## Features

*   **Cyrel DSL:** Intuitive Ruby DSL for constructing complex Cypher queries ([see detailed Cyrel documentation](./CYREL.md)).
*   **ActiveRecord-like Patterns:** Familiar interface for developers accustomed to ActiveRecord.
*   **Rails Integration:** Easy integration into Rails projects via Rails Engine.
*   **Comprehensive Cypher Support:** Aims to support a wide range of Cypher clauses and functions (refer to [`CYREL.md`](./CYREL.md) and `test/cyrel/` for examples).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/seuros/activecypher. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
