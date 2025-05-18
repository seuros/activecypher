# Graph Fixture Profiles

This directory contains **graph fixture profiles** for use with `ActiveCypher::Fixtures`. Each profile defines a self-contained graph universe (nodes and relationships) for deterministic, connection-aware test setup.

## What is a Profile?

A profile is a Ruby file (e.g., `default.rb`, `cold_start.rb`) that describes a graph using a simple DSL:

```ruby
node :lucy,  PersonNode,  name: "Lucy", age: 29
node :mike,  PersonNode,  name: "Mike", age: 34
node :acme,  CompanyNode, name: "Acme Inc"

relationship :match,    :lucy, :LIKES,   :mike,  since: 2023
relationship :employee, :lucy, :WORKS_FOR, :acme, position: "QA"
```

- **Nodes**: `node :ref, ModelClass, props`
- **Relationships**: `relationship :ref, :from_ref, :TYPE, :to_ref, props`

## Usage

In your tests:

```ruby
ActiveCypher::Fixtures.load(profile: :cold_start)
lucy = ActiveCypher::Fixtures[:lucy]
```

- The profile file must exist as `test/fixtures/graph/cold_start.rb`.
- The default profile is `default.rb`.

## Rules

- No nested folders; all profiles live directly in this directory.
- No YAML or non-Ruby formats.
- Each `:ref` must be unique within a profile.
- Cross-database relationships are forbidden and will cause core meltdown.

## Profiles

- **default.rb** — Baseline graph for most tests.
- **cold_start.rb** — Minimal graph for cold boot scenarios.
- **rebound_mode.rb** — (Example) For relationship edge-case testing.

Add new profiles as needed for your test scenarios. Document their purpose here.

---

**See the main project README for full DSL reference and rationale.**
