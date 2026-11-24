# LakeScope

LakeScope is a local-first business-intelligence catalogue and lineage explorer for Qlik Cloud, Amazon Athena and the AWS Glue Data Catalog. It stores technical metadata in a local database; it does not copy the business data in your lake or Qlik applications.

## What is working

- Searchable catalogue of tables, views, materialized tables and reporting assets
- Expandable upstream, downstream and complete lineage graph
- Recursive impact analysis for a table or column change
- SQL and schema inspector
- Athena failure and materialization-candidate views
- Documentation and ownership catalogue
- AWS profile connection testing
- Glue inventory, Athena view parsing and 45-day query-history ingestion
- EventBridge Scheduler inventory matched to staging (`-rule-b`) and snapshot (`-rule-c`) datasets
- BAMV definition ingestion from `code/Views`, connected recursively through Glue views to base tables
- CTAS, `CREATE VIEW`, `INSERT` and `MERGE` table-level lineage extraction
- PostgreSQL 17 authoritative metadata store with a preserved SQLite fallback
- Neo4j Community graph projection for deterministic upstream, downstream and complete traversal
- Automatic graph synchronization after AWS and code-lineage refreshes
- Qlik Cloud spaces, reports/apps, QVD files, data-model metrics, non-secret connection inventory and reload history
- End-to-end Qlik-to-AWS lineage using Qlik resource identifiers first and deterministic table/QVD matching only when needed

LakeScope starts with an empty catalogue. Configure AWS and/or Qlik Cloud in Admin, then run the corresponding Refresh Hub stages to populate every screen with live source metadata.

## Run the installed application

The current local setup uses free Podman containers for PostgreSQL and Neo4j. From Command Prompt or PowerShell (the `.cmd` launcher does not require PowerShell script execution):

```bat
cd C:\PhantomKnight\LakeScope
scripts\run-local.cmd
```

Open `http://127.0.0.1:8000`. The interactive API documentation is at `http://127.0.0.1:8000/docs`.

## First-time setup on another computer

Requirements: Python 3.12+, Node.js, pnpm, Podman Desktop and the Podman engine.

```powershell
cd C:\PhantomKnight\LakeScope
.\scripts\setup-local.ps1
```

Then initialize Podman once and start LakeScope:

```bat
podman machine init --cpus 4 --memory 6144 --disk-size 50 lakescope-machine
scripts\run-local.cmd
```

For live frontend and backend reload during development:

```powershell
.\scripts\dev-local.ps1
```

The development UI runs on `http://127.0.0.1:5173` and proxies API calls to port `8000`.

## Connect to AWS

Open **Admin** in the top bar and sign in with the current local-development password:

```text
pointbreak
```

The admin panel accepts either:

- An AWS access key ID, secret access key and optional temporary session token
- An AWS CLI profile, preferably configured through IAM Identity Center

Static credentials are held only in browser/server process memory for the current connection test and scan. They are not written to SQLite, logs, or frontend source. For an AWS CLI profile:

```powershell
aws configure sso --profile datalake-dev
aws sso login --profile datalake-dev
```

In the admin panel, enter:

- Profile: `datalake-dev`
- AWS region containing Athena and Glue
- Glue catalog, normally `AwsDataCatalog`
- Athena workgroup, normally `primary`

Use **Test credentials**, then open **Refresh Hub**. A full refresh reads Glue tables and views, loads EventBridge schedule configurations, parses lineage, optionally backfills Athena query history, and finalizes the dashboard metrics. Every stage can also be run independently.

The view-lineage stage also reads the supplied BAMV transformation definitions from `code/Views`. It enriches only BAMV tables that already exist in the connected Glue catalogue; repository-only definitions and unresolved objects are not added as catalogue placeholders. The reference code is parsed but never executed by LakeScope.

After updating files under `code/Views`, open **Refresh Hub** and use **Refresh from code** in the Latest refresh panel. This local-only refresh does not call AWS. It reparses all matching definitions, updates changed source edges, removes stale code-derived edges, and reports missing or unresolved definitions in the live log.

The password is intentionally a local-development default. Change `LAKESCOPE_ADMIN_PASSWORD` before allowing any other computer to access the application.

The AWS principal needs read-only access to Glue metadata, Athena workgroups and query executions. It also needs `sts:GetCallerIdentity` plus `scheduler:ListScheduleGroups`, `scheduler:ListSchedules` and `scheduler:GetSchedule` for the EventBridge stage. If schedule-group listing is unavailable, LakeScope safely falls back to the `default` schedule group. Lake Formation policies can restrict protected view definitions even when Glue metadata is visible.

## Connect to Qlik Cloud

In **Admin**, enter the HTTPS URL for the Qlik Cloud tenant and a Qlik API key, test the connection, and save it for the current browser tab. The key is passed only with each refresh request and is not stored in PostgreSQL or Neo4j.

Refresh Hub provides independent stages for the connection, spaces, reports/apps, QVD files, application data models, non-secret data connections, resource-level lineage, reload history, and the final Neo4j merge. Run **Refresh all Qlik metadata** after the AWS scan to build the broadest possible `AWS table/view → QVD/source → Qlik report` graph. API access remains limited to the spaces and apps visible to the Qlik user represented by the key.

## Local data and configuration

- Authoritative database: PostgreSQL 17 in the `lakescope_postgres_data` Podman volume
- Lineage projection: Neo4j Community in the `lakescope_neo4j_data` Podman volume
- Preserved fallback/rollback database: `data/lakescope.db`
- Runtime configuration: copy `.env.example` to `.env` and adjust values
- API and Qlik/AWS collector implementation: `backend/app`
- Frontend implementation: `src`
- BAMV materialization reference: `code`
- Original frontend mockups and design-system export: `design-reference`
- Original supplied source archives: `source-archives`
- Tests: `backend/tests`

`LAKESCOPE_DATABASE_URL` can point to PostgreSQL or SQLite. The checked local `.env` is ignored by source control and currently selects PostgreSQL plus Neo4j graph mode.

The complete persistence and relationship design is documented in `ARCHITECTURE.md`. Neo4j is a projection, not an additional source of truth, and can be rebuilt through `POST /api/graph/sync` or automatically after a successful metadata refresh.

## Validate the project

```powershell
.\.venv\Scripts\python.exe -m pytest backend
pnpm build
```

The API contract includes `/api/estate/summary`, `/api/assets`, `/api/lineage`, `/api/lineage/options`, `/api/impact`, `/api/health/*`, `/api/connections/*`, `/api/scans/latest` and `/api/qlik/scans/latest`.
