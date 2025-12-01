## [Unreleased]

## [0.12.1](https://github.com/seuros/activecypher/compare/active_cypher/v0.12.0...active_cypher/v0.12.1) (2025-12-01)


### Bug Fixes

* require async-pool &gt;= 0.11 and track pool usage ([#62](https://github.com/seuros/activecypher/issues/62)) ([0fa1533](https://github.com/seuros/activecypher/commit/0fa1533887deaaf579cfb60cba065c345a1a5b33))

## [0.12.0](https://github.com/seuros/activecypher/compare/active_cypher/v0.11.2...active_cypher/v0.12.0) (2025-10-19)


### Features

* Improve multi-role connection handling and coverage ([#59](https://github.com/seuros/activecypher/issues/59)) ([0e09afe](https://github.com/seuros/activecypher/commit/0e09afe83595c01c2f82cb84839172065191ae78))

## [0.11.2](https://github.com/seuros/activecypher/compare/active_cypher/v0.11.1...active_cypher/v0.11.2) (2025-09-16)


### Bug Fixes

* Handle UUID for neo4j adapter ([#57](https://github.com/seuros/activecypher/issues/57)) ([4330049](https://github.com/seuros/activecypher/commit/4330049d062086b53590cab84384adc42a176de5))

## [0.11.1](https://github.com/seuros/activecypher/compare/active_cypher/v0.11.0...active_cypher/v0.11.1) (2025-09-05)


### Bug Fixes

* remove abstractions after months of testing ([#54](https://github.com/seuros/activecypher/issues/54)) ([c4746f9](https://github.com/seuros/activecypher/commit/c4746f9f637b5b8997c1f27dbc8b7784f710d5be))
* remove defensive coding ([#56](https://github.com/seuros/activecypher/issues/56)) ([a641d10](https://github.com/seuros/activecypher/commit/a641d10d40c580939561647383ad4d2a0e5a1b96))

## [0.11.0](https://github.com/seuros/activecypher/compare/active_cypher/v0.10.6...active_cypher/v0.11.0) (2025-07-23)


### Features

* show version and health in connection ([#51](https://github.com/seuros/activecypher/issues/51)) ([4d39bde](https://github.com/seuros/activecypher/commit/4d39bde22d46fbfff444c0e17c21188218563662))

## [0.10.6](https://github.com/seuros/activecypher/compare/active_cypher/v0.10.5...active_cypher/v0.10.6) (2025-07-14)


### Bug Fixes

* test transaction and async ([#49](https://github.com/seuros/activecypher/issues/49)) ([bc00e61](https://github.com/seuros/activecypher/commit/bc00e61ea4a0477e9427e45c50a43568f950d957))

## [0.10.5](https://github.com/seuros/activecypher/compare/active_cypher/v0.10.4...active_cypher/v0.10.5) (2025-07-07)


### Bug Fixes

* refactor querying and relationships to use Cyrel DSL consistently ([#47](https://github.com/seuros/activecypher/issues/47)) ([341b448](https://github.com/seuros/activecypher/commit/341b448ce2a8b0b4ac8af6a3bb97cd8d4cfd4aa7))

## [0.10.4](https://github.com/seuros/activecypher/compare/active_cypher/v0.10.3...active_cypher/v0.10.4) (2025-06-17)


### Bug Fixes

* handle wrong env ([#45](https://github.com/seuros/activecypher/issues/45)) ([9829473](https://github.com/seuros/activecypher/commit/9829473acadbf62ad19026ac08eea798b8f088d9))

## [0.10.3](https://github.com/seuros/activecypher/compare/active_cypher/v0.10.2...active_cypher/v0.10.3) (2025-06-08)


### Bug Fixes

* add validation in relationship ([#43](https://github.com/seuros/activecypher/issues/43)) ([44edd26](https://github.com/seuros/activecypher/commit/44edd26b8c0bd7590f26df51c87e6b1b793ecd9a))

## [0.10.2](https://github.com/seuros/activecypher/compare/active_cypher/v0.10.1...active_cypher/v0.10.2) (2025-06-08)


### Bug Fixes

* implement missing relationship persistence methods ([#41](https://github.com/seuros/activecypher/issues/41)) ([8e966d8](https://github.com/seuros/activecypher/commit/8e966d8ff38fac5dabb2ebfc21086921de244803))

## [0.10.1](https://github.com/seuros/activecypher/compare/active_cypher/v0.10.0...active_cypher/v0.10.1) (2025-06-08)


### Bug Fixes

* allow keyword arguments in Relationship#initialize ([#39](https://github.com/seuros/activecypher/issues/39)) ([961bb0e](https://github.com/seuros/activecypher/commit/961bb0ea1b592527b397ff2f15e7166732c31f45))

## [0.10.0](https://github.com/seuros/activecypher/compare/active_cypher/v0.9.0...active_cypher/v0.10.0) (2025-06-05)


### Features

* add create and find_by to relationship ([#37](https://github.com/seuros/activecypher/issues/37)) ([0becbae](https://github.com/seuros/activecypher/commit/0becbae6e2df9fbd64956ca66d81060b74470be8))

## [0.9.0](https://github.com/seuros/activecypher/compare/active_cypher/v0.8.2...active_cypher/v0.9.0) (2025-06-05)


### Features

* add find_by ([#36](https://github.com/seuros/activecypher/issues/36)) ([0d73b6a](https://github.com/seuros/activecypher/commit/0d73b6a9bdd208972394420c28370ec76ab2d113))


### Bug Fixes

* test unwind ([#34](https://github.com/seuros/activecypher/issues/34)) ([7e3f3cb](https://github.com/seuros/activecypher/commit/7e3f3cbd61583faa09bd500cd9d82063966b2d2a))

## [0.8.2](https://github.com/seuros/activecypher/compare/active_cypher/v0.8.1...active_cypher/v0.8.2) (2025-05-30)


### Bug Fixes

* add support to float and bigdecimal ([#32](https://github.com/seuros/activecypher/issues/32)) ([225a9d6](https://github.com/seuros/activecypher/commit/225a9d647dd277988399d6d404f83e8cdea92425))

## [0.8.1](https://github.com/seuros/activecypher/compare/active_cypher/v0.8.0...active_cypher/v0.8.1) (2025-05-30)


### Bug Fixes

* update test coverage and expose connected? ([#30](https://github.com/seuros/activecypher/issues/30)) ([402d87b](https://github.com/seuros/activecypher/commit/402d87b13e2159c6c71c423f84f60cca63a751d9))

## [0.8.0](https://github.com/seuros/activecypher/compare/active_cypher/v0.7.3...active_cypher/v0.8.0) (2025-05-26)


### Features

* add UNWIND clause support ([89a5b29](https://github.com/seuros/activecypher/commit/89a5b29a9fc0cd6733374d195a97bfbb905f9bcf))
* finalize Cyrel ([597e588](https://github.com/seuros/activecypher/commit/597e5889b3f109acf4c8b58b76c5aea4ff965b0e))
* finalize CYREL ([33fcb53](https://github.com/seuros/activecypher/commit/33fcb5338521de1b7a769b10d4f5d71e31751166))
* implement AST-based limit and skip nodes with caching ([a8e14f3](https://github.com/seuros/activecypher/commit/a8e14f3b39d7ea2d686c4ead82df4e0861aabc32))


### Bug Fixes

* autoloading issue ([8380ba5](https://github.com/seuros/activecypher/commit/8380ba5222ed1e7381be3d66f50f4f96ffe5dae5))
* secure form injections ([4a0d729](https://github.com/seuros/activecypher/commit/4a0d72959a0107f37a755a15bdbe018dbcd3d92f))

## [0.7.3](https://github.com/seuros/activecypher/compare/active_cypher/v0.7.2...active_cypher/v0.7.3) (2025-05-24)


### Bug Fixes

* add support for +s ([607790b](https://github.com/seuros/activecypher/commit/607790b590cf2624d79d036e32a8350f7cf02118))
* replace deprecated id() with adapter-aware node_id() in Cyrel queries ([536301d](https://github.com/seuros/activecypher/commit/536301d0119b8c7b6e37542898f4196648b584a0))
* unify internal_id handling for Neo4j and Memgraph adapters ([14dbbcb](https://github.com/seuros/activecypher/commit/14dbbcb163d00f53242d3aa5e0140662499d8d8c))

## [0.7.2](https://github.com/seuros/activecypher/compare/active_cypher/v0.7.1...active_cypher/v0.7.2) (2025-05-24)


### Bug Fixes

* extracts persistence-related operations into adapter ([#26](https://github.com/seuros/activecypher/issues/26)) ([5e19ed1](https://github.com/seuros/activecypher/commit/5e19ed14daed7232824b59c8a710005498eda6a3))

## [0.7.1](https://github.com/seuros/activecypher/compare/active_cypher/v0.7.0...active_cypher/v0.7.1) (2025-05-21)


### Bug Fixes

* add schema tasks ([5dd0c90](https://github.com/seuros/activecypher/commit/5dd0c902951f6649247403369af982e78db3bf6d))

## [0.7.0](https://github.com/seuros/activecypher/compare/active_cypher/v0.6.3...active_cypher/v0.7.0) (2025-05-21)


### Features

* add migrations ([#22](https://github.com/seuros/activecypher/issues/22)) ([71eeae8](https://github.com/seuros/activecypher/commit/71eeae8333c221cff214e651239cd37c6b072594))
* schema dumper ([#24](https://github.com/seuros/activecypher/issues/24)) ([1a91bc7](https://github.com/seuros/activecypher/commit/1a91bc7fe486be8b7599d1a7263f8912a937a027))


### Bug Fixes

* generate relationship classes as string ([#21](https://github.com/seuros/activecypher/issues/21)) ([e5b0bee](https://github.com/seuros/activecypher/commit/e5b0bee13ed2373d5f30e943ccc5e1d7a751d5d0))
* hide sensitive keys in non rails context ([13df977](https://github.com/seuros/activecypher/commit/13df977769462df58f2307eebf7cef8c6efb2859))

## [0.6.3](https://github.com/seuros/activecypher/compare/active_cypher/v0.6.2...active_cypher/v0.6.3) (2025-05-19)


### Bug Fixes

* add version helper ([#17](https://github.com/seuros/activecypher/issues/17)) ([d7288ab](https://github.com/seuros/activecypher/commit/d7288ab15845852c09b7ec558e3fa7b5dcb4be5c))
* redact credentials. ([#16](https://github.com/seuros/activecypher/issues/16)) ([8a29bc0](https://github.com/seuros/activecypher/commit/8a29bc059b7770aa4373985658781e29a9c79709))

## [0.6.2](https://github.com/seuros/activecypher/compare/active_cypher/v0.6.1...active_cypher/v0.6.2) (2025-05-19)


### Bug Fixes

* DRY the connection logic ([f851190](https://github.com/seuros/activecypher/commit/f8511903482aa1de4095c18a20f886e4e3569707))

## [0.6.1](https://github.com/seuros/activecypher/compare/active_cypher/v0.6.0...active_cypher/v0.6.1) (2025-05-19)


### Bug Fixes

* use ssc in driver ([5755335](https://github.com/seuros/activecypher/commit/5755335265b93df476341abf996689dc2a7eb690))

## [0.6.0](https://github.com/seuros/activecypher/compare/active_cypher/v0.5.0...active_cypher/v0.6.0) (2025-05-19)


### Features

* add fixtures interface ([#13](https://github.com/seuros/activecypher/issues/13)) ([4d98480](https://github.com/seuros/activecypher/commit/4d98480544742fab400865846afac69d35efba70))
* refactor to link Relationship with Node with a DSL. ([#12](https://github.com/seuros/activecypher/issues/12)) ([97ff9d0](https://github.com/seuros/activecypher/commit/97ff9d09bb4ae6d94a527c020f77a69e1b67c845))
* Relationship Base and Node Base Convention ([d9328a8](https://github.com/seuros/activecypher/commit/d9328a83fb6a3cbeed4e7ef86dc2e5ed5ffcd4e2))


### Bug Fixes

* load_multi_db fix ([9321d73](https://github.com/seuros/activecypher/commit/9321d737f28c0f940b3e2f96f45f0328c45e109a))

## [0.5.0](https://github.com/seuros/activecypher/compare/active_cypher/v0.4.1...active_cypher/v0.5.0) (2025-05-16)


### Features

* Add consistent, descriptive comments to all Cyrel DSL helpers ([#9](https://github.com/seuros/activecypher/issues/9)) ([5a5824c](https://github.com/seuros/activecypher/commit/5a5824c27b0aedfa2304d6bd741c5e0b241abbb6))
* expose adapter_class ([#8](https://github.com/seuros/activecypher/issues/8)) ([4ef9259](https://github.com/seuros/activecypher/commit/4ef92593b9d9ef66ae41262236401c98d051911f))


### Bug Fixes

* name node correctly ([c868d2b](https://github.com/seuros/activecypher/commit/c868d2b4d5f97a97076a2bd3913752d614ade98f))
* name node correctly ([c6c3fed](https://github.com/seuros/activecypher/commit/c6c3fed440bbe4451b0e3c27273502d103892403))
* name node correctly ([#6](https://github.com/seuros/activecypher/issues/6)) ([5d5fe9f](https://github.com/seuros/activecypher/commit/5d5fe9f1cbcdf78b97233efdf7e22142cc837c8e))

## [0.4.1](https://github.com/seuros/activecypher/compare/active_cypher/v0.4.0...active_cypher/v0.4.1) (2025-05-13)


### Bug Fixes

* Fix generator templates and enforce class collision checks ([8ad926a](https://github.com/seuros/activecypher/commit/8ad926a264904dcc54842baa86ab7924edd33dfc))
* Fix generator templates and enforce class collision checks ([3725218](https://github.com/seuros/activecypher/commit/372521819860e24be785d6fd18f73dc105245196))

## [0.4.0](https://github.com/seuros/activecypher/compare/active_cypher/v0.3.0...active_cypher/v0.4.0) (2025-05-12)


### Features

* Re-added Instrumentation to ActiveCypher ([eccf775](https://github.com/seuros/activecypher/commit/eccf775fb1f4d79e9d856184ace21ec6822de797))
* readd instrumentation ([d6658fa](https://github.com/seuros/activecypher/commit/d6658fa1e2231b36f60a512f8418437520abe8ea))

## [0.3.0](https://github.com/seuros/activecypher/compare/active_cypher-v0.2.0...active_cypher/v0.3.0) (2025-05-12)


### Features

* activecypher — now your graphs can feel pain ([192b0ef](https://github.com/seuros/activecypher/commit/192b0ef3b48267b592c5340dee70695ac000b642))
* cyrel A powerful Domain Specific Language (DSL) for building Cypher queries programmatically in Ruby. ([8bc1780](https://github.com/seuros/activecypher/commit/8bc178084f5b03b279bb54fa64935876f83e32a3))


### Bug Fixes

* avoid throwing tantrum when config file is not there. ([3522f40](https://github.com/seuros/activecypher/commit/3522f404b3c95a7e85c3eba4d67f5bef9c630557))
* don't blow when config file is missing ([a4128ce](https://github.com/seuros/activecypher/commit/a4128cec90d11d238b9852b175e541558ee09c2b))

## [0.1.0] - 2023-06-01

- Initial release
