# LakeScope local data architecture

## Design decision

LakeScope uses a hybrid persistence model:

- **PostgreSQL 17** is the authoritative metadata and operational store.
- **Neo4j Community 5.26** is a rebuildable graph projection used for fast lineage traversal.
- **SQLite** remains a no-service fallback and the original `data/lakescope.db` is retained as a rollback copy.

This is not a vector database design. Every impact answer is produced from explicit, versioned `FEEDS` relationships, so results are deterministic and explainable. AI can be added later for descriptions or natural-language search without making it responsible for lineage truth.

## Relational model

| Table                   | Purpose                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------- |
| `data_assets`           | One Glue/Athena object, identified by a unique FQN                                    |
| `asset_columns`         | Ordered schema columns belonging to an asset                                          |
| `lineage_edges`         | Directed source-to-consumer dependency with evidence and confidence                   |
| `query_runs`            | Athena history used as lineage/health evidence                                        |
| `refresh_schedules`     | EventBridge Scheduler configuration and its optional asset association                |
| `scan_runs`             | Durable refresh progress and live logs                                                |
| `source_connections`    | Non-secret AWS connection metadata and status                                         |
| `qlik_resources`        | Qlik app, QVD and lineage-node identity, QRI, space, owner and operational metrics    |
| `qlik_spaces`           | Qlik space inventory                                                                  |
| `qlik_data_files`       | QVD path, size, ownership and file lifecycle metadata                                 |
| `qlik_app_tables`       | Qlik associative data-model table/row/field/size metrics                              |
| `qlik_data_connections` | Non-secret Qlik connection inventory; credentials and connection strings are excluded |
| `qlik_reloads`          | Per-app reload status, timing and error history                                       |
| `admin_sessions`        | Expiring local administrator sessions                                                 |

The relationship direction is always:

```text
upstream source ──FEEDS──> downstream consumer
```

## Graph projection

Each PostgreSQL asset becomes a `LakeScopeAsset` node. Each relational lineage edge becomes a `FEEDS` relationship and keeps the relational edge ID, evidence source, confidence, inference flag and query execution ID.

Projection refreshes use a generation marker. The new generation is merged first; stale LakeScope-managed relationships and nodes are removed only after all new batches have been written. Neo4j never becomes the sole copy of metadata and can be rebuilt at any time from PostgreSQL.

Lineage traversal uses a bounded breadth-first search (maximum 16 layers). This avoids enumerating every possible path in a densely nested view graph. The `upstream`, `downstream` and `complete` scopes were verified against the original relational traversal.

## Refresh flow

```text
AWS Glue + EventBridge Scheduler + Athena + code/Views
                         |
                         v
                  PostgreSQL metadata
                         ^
                         |
Qlik apps + QVDs + data models + lineage + reloads
                         |
                         v
                Neo4j graph projection
                         |
                         v
                 Lineage and impact API
```

AWS credentials and Qlik API keys remain in process/browser memory for the scan request and are not stored in PostgreSQL or Neo4j. Qlik lineage QRIs are preferred as immutable joins. Name matching is accepted only when it resolves to exactly one AWS or QVD asset.

## Local services

The services are defined in `compose.yaml`, listen only on `127.0.0.1`, and use Podman-managed persistent volumes.

- PostgreSQL: `127.0.0.1:5432`
- Neo4j Browser: `http://127.0.0.1:7474`
- Neo4j Bolt: `127.0.0.1:7687`

Use `scripts/start-databases.cmd` and `scripts/stop-databases.cmd`. Stopping services preserves the database volumes.
