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

*(Details on configuring the database connection will be added here. This typically involves creating an initializer file in a Rails application, e.g., `config/initializers/active_cypher.rb`, to specify connection details for your graph database like Neo4j.)*

```ruby
# config/initializers/active_cypher.rb (Example - Needs specific implementation)
# ActiveCypher.configure do |config|
#   config.driver = Neo4j::Driver::GraphDatabase.driver('bolt://localhost:7687', Neo4j::Driver::AuthTokens.basic('user', 'password'))
# end
```

## Usage

ActiveCypher allows you to define models representing nodes in your graph and use the `Cyrel` DSL to build queries.

**Example: Defining a Model (Conceptual)**

*(Actual model definition might differ based on gem implementation)*

```ruby
# class Person
#   include ActiveCypher::Node
#   attribute :name, type: String
#   attribute :born, type: Integer
# end
```

**Example: Querying with Cyrel**

```ruby
# Find a person named 'Alice'
# query = Person.match(p).where(p[:name].eq('Alice')).return(p)
# results = query.execute

# Create a new person
# create_query = Person.create(p: { name: 'Bob', born: 1994 }).return(p)
# new_person = create_query.execute

# Find people born after 1985
# born_after_query = Person.match(p).where(p[:born] > 1985).return(p[:name], p[:born])
# recent_people = born_after_query.execute
```

*(More detailed usage examples covering various Cyrel features like MATCH, CREATE, MERGE, WHERE, RETURN, ORDER BY, LIMIT, etc., will be added based on the final implementation and test cases.)*

## Features

*   **Cyrel DSL:** Intuitive Ruby DSL for constructing complex Cypher queries.
*   **ActiveRecord-like Patterns:** Familiar interface for developers accustomed to ActiveRecord.
*   **Rails Integration:** Easy integration into Rails projects via Rails Engine.
*   **Comprehensive Cypher Support:** Aims to support a wide range of Cypher clauses and functions (refer to `test/cyrel/` for examples).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `lib/active_cypher/version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/seuros/activecypher. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActiveCypher project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/seuros/activecypher/blob/master/CODE_OF_CONDUCT.md). *(Note: The CODE_OF_CONDUCT.md file might need to be created)*
