# ActiveCypher Examples

This guide demonstrates how to work with nodes and relationships in ActiveCypher using a coffee supply chain as an example. Because let's face it, most developers run on caffeine anyway. ☕️

## Basic Setup

First, ensure your application has the base classes generated:

```bash
bin/rails generate active_cypher:install
```

This creates:
- `app/graph/application_graph_node.rb` - Base class for all nodes
- `app/graph/application_graph_relationship.rb` - Base class for all relationships  
- `config/cypher_databases.yml` - Database configuration

## Creating Nodes

### Coffee Bean Node

```ruby
# app/graph/coffee_bean_node.rb
class CoffeeBeanNode < ApplicationGraphNode
  attribute :variety, :string        # e.g., "Arabica", "Robusta"
  attribute :origin, :string         # e.g., "Colombia", "Ethiopia"
  attribute :harvest_date, :date
  attribute :quality_score, :float   # 1-100 scale (Float support enabled)
  attribute :processing_method, :string # "washed", "natural", "honey"
  
  validates :variety, presence: true
  validates :quality_score, inclusion: { in: 1..100 }
end
```

### Coffee Shop Node

```ruby
# app/graph/coffee_shop_node.rb
class CoffeeShopNode < ApplicationGraphNode
  attribute :name, :string
  attribute :location, :string
  attribute :established_year, :integer
  attribute :chain, :boolean, default: false
  attribute :specialty, :string      # "espresso", "pour_over", "cold_brew"
  
  validates :name, presence: true
  validates :established_year, numericality: { greater_than: 1900 }
end
```

### Roastery Node

```ruby
# app/graph/roastery_node.rb
class RoasteryNode < ApplicationGraphNode
  attribute :name, :string
  attribute :location, :string
  attribute :capacity_bags_per_day, :integer
  attribute :roast_profiles, :json   # Array of available roast levels
  attribute :certified_organic, :boolean, default: false
  
  validates :name, presence: true
  validates :capacity_bags_per_day, numericality: { greater_than: 0 }
end
```

## Creating Relationships

### Supply Relationship

```ruby
# app/graph/supplies_rel.rb
class SuppliesRel < ApplicationGraphRelationship
  # Relationships inherit connection from ApplicationGraphNode by default
  # No need to specify connects_to unless you want custom connection handling and like problems
  
  attribute :quantity_bags, :integer
  attribute :price_per_bag, :decimal
  attribute :contract_date, :date
  attribute :delivery_schedule, :string  # "weekly", "monthly", "seasonal"
  
  validates :quantity_bags, numericality: { greater_than: 0 }
  validates :price_per_bag, numericality: { greater_than: 0 }
end
```

### Roasts Relationship

```ruby
# app/graph/roasts_rel.rb
class RoastsRel < ApplicationGraphRelationship
  attribute :roast_level, :string     # "light", "medium", "dark"
  attribute :roast_date, :date
  attribute :batch_size_kg, :float
  attribute :roast_profile, :json     # Temperature curve, timing, etc.
  attribute :cupping_score, :float    # Quality assessment after roasting
  
  validates :roast_level, inclusion: { in: %w[light medium dark] }
  validates :batch_size_kg, numericality: { greater_than: 0 }
end
```

### Serves Relationship

```ruby
# app/graph/serves_rel.rb
class ServesRel < ApplicationGraphRelationship
  attribute :blend_name, :string      # Custom name for the coffee offering
  attribute :price_per_cup, :decimal
  attribute :daily_volume_cups, :integer
  attribute :brewing_method, :string  # "espresso", "drip", "french_press"
  attribute :seasonal_offering, :boolean, default: false
  
  validates :price_per_cup, numericality: { greater_than: 0 }
  validates :brewing_method, presence: true
end
```

## Connection Configuration

By default, relationships inherit their database connection from `ApplicationGraphNode`. Connection configuration is set at class definition time and cannot be changed at runtime.

**Important:** Only classes inheriting from `ActiveCypher::Base` can have connections configured. Relationships must follow the convention of using `ApplicationGraphRelationship` as the base class to inherit the connection from `ApplicationGraphNode`.

### Custom Base Classes for Different Databases

If you need to connect to multiple databases, create separate base classes:

```ruby
# app/graph/application_graph_node.rb - Uses primary connection (default)
class ApplicationGraphNode < ActiveCypher::Base
  # No need to specify connects_to - primary is default
end

# app/graph/analytics_graph_node.rb - Analytics database  
class AnalyticsGraphNode < ActiveCypher::Base
  connects_to writing: :analytics_db, reading: :analytics_readonly
end

# Relationships automatically inherit from their corresponding node base
# app/graph/application_graph_relationship.rb
class ApplicationGraphRelationship < ActiveCypher::Relationship
  # Inherits connection from ApplicationGraphNode
end

# app/graph/analytics_graph_relationship.rb
class AnalyticsGraphRelationship < ActiveCypher::Relationship
  # Inherits connection from AnalyticsGraphNode (by naming convention)
end
```

**Note:** Cross-connection operations between different databases are not supported.

## Usage Examples

### Creating and Connecting Entities

```ruby
# Create coffee beans (the foundation of all productivity)
arabica_beans = CoffeeBeanNode.create!(
  variety: "Arabica",
  origin: "Colombia",
  harvest_date: 1.month.ago,
  quality_score: 87.5, # Higher than most code reviews 
  processing_method: "washed"
)

# Create a roastery (where magic happens)
mountain_roasters = RoasteryNode.create!(
  name: "Mountain Peak Roasters",
  location: "Denver, CO", # High altitude = better coffee, obviously
  capacity_bags_per_day: 50,
  roast_profiles: %w[light medium dark], # Like debugging: light warnings, medium errors, dark despair
  certified_organic: true
)

# Create supply relationship (the caffeine lifeline)
supply_contract = SuppliesRel.create!(
  from_node: arabica_beans,
  to_node: mountain_roasters,
  quantity_bags: 20,
  price_per_bag: 180.50, # Cheaper than therapy
  contract_date: Date.current,
  delivery_schedule: "monthly"
)

# Create a coffee shop (developer sanctuary)
specialty_cafe = CoffeeShopNode.create!(
  name: "The Grind Coffee Co.", # Where code is debugged one cup at a time
  location: "Boulder, CO",
  established_year: 2018,
  chain: false, # Independent, like most developers' spirits
  specialty: "pour_over"
)

# Create roasting relationship (transformation magic)
roasting = RoastsRel.create!(
  from_node: mountain_roasters,
  to_node: arabica_beans,
  roast_level: "medium", # Like our bugs: not too light, not too dark
  roast_date: Date.current,
  batch_size_kg: 45.0,
  roast_profile: { "temp_curve": "gradual", "total_time": "12min" }, # Slower than CI/CD pipeline
  cupping_score: 89.2
)

# Create serving relationship (the final delivery)
serving = ServesRel.create!(
  from_node: specialty_cafe,
  to_node: arabica_beans, # Direct from source to your keyboard
  blend_name: "Colombian Mountain Blend",
  price_per_cup: 4.50, # Still cheaper than AWS charges per minute
  daily_volume_cups: 85,
  brewing_method: "pour_over", # Because we're fancy like that
  seasonal_offering: false # Available year-round, unlike good documentation
)
```

### Querying the Supply Chain

```ruby
# Find all coffee shops serving Colombian beans
colombian_suppliers = CoffeeBeanNode.where(origin: "Colombia")
  .joins(:serves_rel)
  .includes(:coffee_shop_nodes)

# Find high-quality beans (score > 85) with their supply contracts
premium_beans = CoffeeBeanNode.where("quality_score > ?", 85)
  .joins(:supplies_rel)
  .includes(:roastery_nodes)

# Find roasteries with organic certification
organic_roasters = RoasteryNode.where(certified_organic: true)

# Get the complete supply chain for a specific coffee shop
cafe = CoffeeShopNode.find_by(name: "The Grind Coffee Co.")
supply_chain = cafe.cypher_query(<<~CYPHER)
  MATCH (shop:CoffeeShopNode {name: $shop_name})
  MATCH (shop)-[serves:SERVES]->(beans:CoffeeBeanNode)
  MATCH (roastery:RoasteryNode)-[roasts:ROASTS]->(beans)
  MATCH (beans)-[supplies:SUPPLIES]->(roastery)
  RETURN shop, serves, beans, roasts, roastery, supplies
CYPHER
```

### Advanced Relationship Queries

```ruby
# Find the most expensive coffee supply contracts
expensive_contracts = SuppliesRel.where("price_per_bag > ?", 200)
  .order(price_per_bag: :desc)
  .includes(:from_node, :to_node)

# Find seasonal coffee offerings
seasonal_coffees = ServesRel.where(seasonal_offering: true)
  .includes(:coffee_shop_nodes, :coffee_bean_nodes)

# Get roasting statistics
roasting_stats = RoastsRel.group(:roast_level)
  .average(:cupping_score)
```

## Database Configuration

Your `config/cypher_databases.yml` should include connection details. The preferred approach is to use `url` format with `GRAPHDB_URL` environment variable:

```yaml
development:
  primary:
    url: <%= ENV.fetch('GRAPHDB_URL', 'neo4j://caffeine_addict:espresso123@localhost:17687/coffee_empire') %>
    
  analytics_db:
    url: neo4j://bean_counter:latte_art@analytics-db.example.com:7687/hipster_metrics

production:
  primary:
    url: <%= ENV['GRAPHDB_URL'] %>
```

Alternative format using individual connection parameters (for those who like their config extra verbose, like a triple-shot americano):

```yaml
development:
  primary:
    adapter: neo4j  # or memgraph (the cooler, younger sibling)
    host: localhost
    port: 17687
    username: barista_supreme
    password: no_decaf_please
    database: coffee_supply_chain
```

## Migration Example

ActiveCypher provides helper methods for common migration operations. Use these instead of raw `execute` statements:

```ruby
# Generate with: bin/rails generate active_cypher:migration CreateCoffeeSupplyChain
class CreateCoffeeSupplyChain < ActiveCypher::Migration
  up do
    # Create uniqueness constraints using helper methods
    create_uniqueness_constraint :CoffeeBeanNode, :id, name: :coffee_bean_id_unique
    create_uniqueness_constraint :RoasteryNode, :name, name: :roastery_name_unique
    create_uniqueness_constraint :CoffeeShopNode, :name, :location, name: :coffee_shop_location_unique
    
    # Create indexes for common queries
    create_node_index :CoffeeBeanNode, :origin, name: :coffee_origin_idx
    create_node_index :CoffeeBeanNode, :quality_score, name: :coffee_quality_idx
    create_node_index :RoasteryNode, :certified_organic, name: :organic_roastery_idx
    create_node_index :CoffeeShopNode, :specialty, name: :coffee_shop_specialty_idx
    
    # Create relationship indexes for performance
    create_rel_index :SUPPLIES, :contract_date, name: :supply_contract_timeline_idx
    create_rel_index :ROASTS, :roast_date, name: :roasting_timeline_idx
    create_rel_index :SERVES, :seasonal_offering, name: :seasonal_coffee_idx
    
    # Use raw execute only for advanced features not covered by helpers
    execute <<~CYPHER
      CREATE FULLTEXT INDEX coffee_search IF NOT EXISTS
      FOR (bean:CoffeeBeanNode) ON EACH [bean.variety, bean.origin, bean.processing_method]
    CYPHER
  end
  
  # Note: No down method needed - migrations are append-only in graph databases
  # Dropping constraints/indexes in production can be dangerous!
end
```

### Available Migration Helper Methods

```ruby
# Node indexes
create_node_index :Label, :property, name: :optional_name
create_node_index :Label, :prop1, :prop2, unique: true  # Composite index

# Relationship indexes  
create_rel_index :REL_TYPE, :property, name: :optional_name

# Uniqueness constraints
create_uniqueness_constraint :Label, :property, name: :optional_name
create_uniqueness_constraint :Label, :prop1, :prop2  # Composite constraint

# Raw Cypher (when helpers don't cover your use case)
execute "CREATE INDEX fancy_index FOR (n:Node) ON (n.computed_property)"
```

This example demonstrates the key concepts of working with ActiveCypher while using a practical, relatable domain that's more interesting than typical user/post examples.
