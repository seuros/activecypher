# Cyrel: A powerful Domain Specific Language (DSL) for building Cypher queries programmatically in Ruby

## 1. Introduction

*   **What is Cyrel?**
    *   An AREL-inspired Domain Specific Language (DSL) for building Cypher queries programmatically in Ruby.
    *   Focuses on generating structured, safe (parameterized) Cypher, abstracting away direct string manipulation.
*   **Purpose & Audience:**
    *   Primarily the query generation engine for `ActiveCypher`.
    *   Can be used directly by developers needing fine-grained control over Cypher query construction outside of the ActiveCypher ORM layer.
*   **Key Benefit:** Abstracts string manipulation, enforces parameterization to prevent injection vulnerabilities, and provides a Ruby-like way to think about Cypher queries.

## 2. Core Concepts

Cyrel organizes query building around several key components:

*   **`Cyrel::Query`:** The central object representing a query being built. It acts as the main entry point, holds the state of various clauses, manages query parameters, and orchestrates the final Cypher generation via `to_cypher`.
*   **Clauses (`Cyrel::Clause::*`)**: Objects representing individual Cypher clauses (`MATCH`, `WHERE`, `CREATE`, `RETURN`, `WITH`, `SET`, `DELETE`, `MERGE`, `OPTIONAL MATCH`, `ORDER BY`, `SKIP`, `LIMIT`, `CALL`). Methods on `Cyrel::Query` (e.g., `query.match(...)`, `query.where(...)`) typically create or modify these internal clause objects.
*   **Patterns (`Cyrel::Pattern::*`)**: Objects representing the graph patterns used in clauses like `MATCH`, `CREATE`, `MERGE`.
    *   `Node`: Represents a node, e.g., `(alias:Label {prop: $param})`. Stores alias, labels, and properties.
    *   `Relationship`: Represents a relationship, e.g., `-[alias:TYPE*.. {prop: $param}]->`. Stores alias, types, direction, properties, and length specifiers.
    *   `Path`: Represents a linear sequence of alternating nodes and relationships.
*   **Expressions (`Cyrel::Expression::*`)**: Objects representing parts of the query that evaluate to a value or condition (e.g., property access `node[:name]`, literals `'Alice'`, function calls `Cyrel.id(node)`, comparisons `node[:age].gt(25)`, logical operators). Used heavily in `WHERE`, `RETURN`, `SET`.
*   **Functions (`Cyrel::Functions`)**: A module providing helper methods (e.g., `Cyrel.id()`, `Cyrel.count()`, `Cyrel.exists()`, `Cyrel.coalesce()`) to generate `Expression::FunctionCall` objects for use in various clauses.

## 3. Getting Started: Basic Query Building

You typically start by creating a `Cyrel::Query` object and then chain methods to build the desired Cypher query.

```ruby
# 1. Define pattern components
person_node = Cyrel::Pattern::Node.new(:person, labels: ['Person'], properties: { name: 'Alice' })
age_condition = person_node[:age].gt(25) # Creates an Expression object

# 2. Build the query
query = Cyrel::Query.new
                    .match(person_node)       # Add a MATCH clause
                    .where(age_condition)     # Add a WHERE clause
                    .return_(person_node[:name]) # Add a RETURN clause (use return_ for Symbol/Expression)

# 3. Generate Cypher and parameters
cypher_string, params_hash = query.to_cypher

puts cypher_string
#=> MATCH (person:Person {name: $p1}) WHERE person.age > $p2 RETURN person.name

puts params_hash
#=> { p1: 'Alice', p2: 25 }
```

*Note: Cyrel automatically assigns parameter keys (like `$p1`, `$p2`) and collects the values.*

## 4. Key Features & Usage Patterns

### Automatic Parameterization

Cyrel is designed to generate parameterized queries by default. When you provide literal values (strings, numbers, booleans) in patterns or expressions, Cyrel automatically converts them into parameters and adds them to the parameter hash returned by `to_cypher`. This is crucial for security (preventing Cypher injection) and often improves database performance.

```ruby
node = Cyrel::Pattern::Node.new(:p, labels: 'Person', properties: { name: 'Bob', active: true })
query = Cyrel::Query.new.match(node).return_(node)

cypher, params = query.to_cypher
# cypher => "MATCH (p:Person {name: $p1, active: $p2}) RETURN p"
# params => { p1: 'Bob', p2: true }
```

### Pattern Matching

Cyrel provides objects to represent nodes, relationships, and paths for use in `MATCH`, `OPTIONAL MATCH`, `CREATE`, and `MERGE` clauses.

```ruby
# Matching nodes with labels and properties
user_node = Cyrel::Pattern::Node.new(:user, labels: ['User'], properties: { email: 'test@example.com' })
query = Cyrel::Query.new.match(user_node).return_(:user)
#=> MATCH (user:User {email: $p1}) RETURN user

# Matching relationships (simple outgoing)
user_node = Cyrel::Pattern::Node.new(:u, labels: ['User'])
rel = Cyrel::Pattern::Relationship.new(types: ['FOLLOWS'], direction: :outgoing)
org_node = Cyrel::Pattern::Node.new(:o, labels: ['Organization'])
path = Cyrel::Pattern::Path.new([user_node, rel, org_node])
query = Cyrel::Query.new.match(path).return_(:u, :o)
#=> MATCH (u:User)-[:FOLLOWS]->(o:Organization) RETURN u, o

# Optional Match (using query.optional_match)
# ... (Example would be similar to match, using optional_match method)

# Path Variables (Handled within the clause logic, e.g., Match)
# ... (Refer to specific clause documentation/tests for assignment syntax if needed)
```

### Data Manipulation

Cyrel supports creating and modifying graph data.

```ruby
# CREATE Node
node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Alice' })
query = Cyrel::Query.new.create(node)
cypher, params = query.to_cypher
# cypher => CREATE (person:Person {name: $p1})
# params => { p1: 'Alice' }

# MERGE Node (Find or Create)
node = Cyrel::Pattern::Node.new(:person, labels: 'Person', properties: { name: 'Bob', age: 30 })
query = Cyrel::Query.new.merge(node)
cypher, params = query.to_cypher
# cypher => MERGE (person:Person {name: $p1, age: $p2})
# params => { p1: 'Bob', p2: 30 }

# SET Properties (Example structure)
# query.match(node).set(node[:last_login] => Time.now)
#=> MATCH (node) SET node.last_login = $p1

# REMOVE Properties/Labels (Example structure)
# query.match(node).remove(node[:temp_prop])
#=> MATCH (node) REMOVE node.temp_prop

# DELETE / DETACH DELETE (Example structure)
# query.match(node).delete(node)
#=> MATCH (node) DELETE node
# query.match(node).detach_delete(node)
#=> MATCH (node) DETACH DELETE node
```

### Advanced Constructs

Cyrel supports many other Cypher features:

*   **`WITH` Clause:** Used to chain query parts and pass results.
    ```ruby
    # query.match(user_node).with(user_node[:name].as(:userName)).return_(:userName)
    #=> MATCH (user) WITH user.name AS userName RETURN userName
    ```
*   **Functions & Expressions:** Build complex conditions and return values.
    ```ruby
    # query.match(node).where(Cyrel.id(node).eq(123)).return_(Cyrel.count(node))
    #=> MATCH (node) WHERE id(node) = $p1 RETURN count(node)
    ```
*   **Ordering, Skipping, Limiting:** Control query results.
    ```ruby
    # query.match(node).return_(node).order_by(node[:name].desc).skip(10).limit(5)
    #=> MATCH (node) RETURN node ORDER BY node.name DESC SKIP 10 LIMIT 5
    ```
*   **`CALL` Procedures/Subqueries:** Execute stored procedures or embedded queries.
    ```ruby
    # query.call { |q| q.match(node).return_(node) } # Example subquery structure
    #=> CALL { MATCH (node) RETURN node }
    ```

### Query Merging

You can combine two `Cyrel::Query` objects using the `merge!` method. This is useful for applying scopes or conditionally adding query parts.

```ruby
query1 = Cyrel::Query.new.match(Cyrel::Pattern::Node.new(:p, labels: 'Person'))
query2 = Cyrel::Query.new.where(Cyrel['p'][:age].gt(30)).return_('p.name')

query1.merge!(query2)
cypher, params = query1.to_cypher

# cypher => MATCH (p:Person) WHERE p.age > $p1 RETURN p.name
# params => { p1: 30 }
```
*   **Behavior:**
    *   Parameters are combined (re-keyed if necessary).
    *   Additive clauses (`MATCH`, `CREATE`, `SET`, etc.) are appended.
    *   `WHERE` clauses are combined using `AND`.
    *   `RETURN` expressions are combined (appended).
    *   `ORDER BY`, `SKIP`, `LIMIT` are typically overwritten by the merged query's values if present.
    *   *Alias Conflicts:* Merging will raise a `Cyrel::AliasConflictError` if the queries try to define the same alias with incompatible properties (e.g., different labels).

## 5. Example Workflow (Conceptual)

```ruby
# Find active users, load their recent orders, create a 'VIEWED' relationship, return user name and order count.

user_node = Cyrel::Pattern::Node.new(:u, labels: 'User')
order_node = Cyrel::Pattern::Node.new(:o, labels: 'Order')
viewed_rel = Cyrel::Pattern::Relationship.new(types: ['VIEWED'], direction: :outgoing)

query = Cyrel::Query.new
          .match(user_node)                                      # Match users
          .where(user_node[:status].eq('active'))                # Filter active ones
          .optional_match(Cyrel::Pattern::Path.new([user_node, Cyrel::Pattern::Relationship.new(types: ['HAS_ORDER']), order_node])) # Load orders
          .where(order_node[:created_at].gt(Date.today - 30))    # Filter recent orders
          .with(user_node, Cyrel.collect(order_node).as(:orders)) # Group orders per user
          .merge(Cyrel::Query.new.create(Cyrel::Pattern::Path.new([user_node, viewed_rel, Cyrel.literal('ProductX')]))) # Create VIEWED rel (conceptual)
          .return_(user_node[:name], Cyrel.size(:orders).as(:order_count)) # Return name and order count

# cypher, params = query.to_cypher
# (Generated Cypher would reflect the chained clauses)
```

## 6. Relationship with ActiveCypher

Cyrel serves as the underlying query builder for the `ActiveCypher` library. When you use ActiveCypher methods like `User.where(name: 'Alice').first` or define associations and scopes, ActiveCypher uses Cyrel internally to construct the appropriate Cypher query string and parameters before sending it to the Graph database. While most developers interact with ActiveCypher's higher-level API, understanding Cyrel can be helpful for debugging or building very complex queries.

## 7. Generating the Query String and Parameters

The final step in using Cyrel is always calling the `to_cypher` method on your `Cyrel::Query` object.

```ruby
cypher_string, params_hash = query.to_cypher
```

*   `cypher_string`: A String containing the generated Cypher query with parameter placeholders (e.g., `$p1`, `$p2`).
*   `params_hash`: A Hash containing the mapping between the placeholders and their actual values (e.g., `{ p1: 'Alice', p2: 30 }`).

This pair is typically what you would pass to your connection adapter for execution.