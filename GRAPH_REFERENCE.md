# Graph Database Quick Reference

For detailed ActiveCypher Ruby gem usage, see the main [README.md](README.md).

## Direct Database Access

### Connection Commands
```bash
# Neo4j
cypher-shell -u neo4j -p activecypher

# Memgraph
mgconsole --host localhost --port 17688 --username memgraph --password activecypher --use-ssl=false
```

### Environment Variables
```bash
NEO4J_URL="neo4j://neo4j:activecypher@localhost:17687"
GRAPHDB_URL="memgraph://memgraph:activecypher@localhost:17688"
```

### Basic Cypher Queries
```cypher
-- Create nodes
CREATE (p:Person {name: 'Alice', age: 30});

-- Match nodes
MATCH (p:Person) RETURN p;
MATCH (p:Person {name: 'Alice'}) RETURN p;

-- Create relationships
MATCH (p1:Person {name: 'Alice'}), (p2:Person {name: 'Bob'})
CREATE (p1)-[:KNOWS]->(p2);

-- Match relationships
MATCH (p1:Person)-[r:KNOWS]->(p2:Person) RETURN p1.name, p2.name;

-- Count nodes
MATCH (n) RETURN count(n);

-- Delete
MATCH (p:Person {name: 'Alice'}) DELETE p;
```

### Shell Commands
```bash
# Execute from file
cypher-shell -u neo4j -p activecypher < queries.cypher
mgconsole --host localhost --port 17688 --username memgraph --password activecypher < queries.cypher

# Single query
echo "MATCH (n) RETURN count(n);" | cypher-shell -u neo4j -p activecypher
echo "MATCH (n) RETURN count(n);" | mgconsole --host localhost --port 17688 --username memgraph --password activecypher

# Exit shell
:exit (Neo4j)
:quit (Memgraph)
# Note: Unlike Vim, you can actually exit these shells! 😉
```
