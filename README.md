# ClickHouse meter playground

A local practice environment for a smart-meter project (electricity and water readings): **ClickHouse**, an **S3 bucket** with raw Parquet files, and **dbt**, all in Docker. It comes with 57 exercises with automatic answer checking.

```
S3 bucket (raw Parquet files)  ──►  ClickHouse (tables, all SQL work)  ──►  dbt (models + tests, run in order)
```

## What you need

- Docker Desktop (or OrbStack / Colima), with about 4 GB of RAM and 3 GB of free disk
- Nothing else: dbt runs in a container, so no Python install is needed

## Setup (once, about 10 minutes)

```bash
git clone <this repo>
cd <repo folder>
./setup.sh
```

`setup.sh` does the following:

- creates a `.env` file with random passwords (it is git-ignored, so passwords are never committed);
- starts ClickHouse and the S3 bucket;
- generates the `meters` dataset;
- writes the readings to the bucket as daily Parquet files;
- downloads the public `imdb`, `uk` and `nyc_taxi` datasets from ClickHouse's public bucket;
- builds the dbt image.

You can re-run it at any time to reset the datasets. Use `./setup.sh --no-public` to skip the slow download.

**Port already in use?** If 8123, 9000 or 8333 is taken, add `CH_HTTP_PORT=18123` (and/or `CH_TCP_PORT`, `S3_PORT`) to `.env` and re-run.

## Connect

| What | How |
|---|---|
| Web UI | http://localhost:8123/play: user `admin`, password = `CLICKHOUSE_PASSWORD` in `.env` |
| Terminal | `docker compose exec clickhouse clickhouse-client` |
| DBeaver / DataGrip | host `localhost`, port `8123`, same user and password |
| dbt | `docker compose run --rm dbt build` (models in `dbt/meter_project/`) |
| Public big-data playground | https://sql.clickhouse.com (read-only, used by the "Browser" exercises) |

## The exercises

The exercises live on an interactive page; ask the repo owner for the link. For each exercise you write your SQL, paste the result, and the page checks it against the expected answer. Your SQL and progress are saved to your own account and are private to you. A copy of the page is in `exercises/meter-drills.html`.

| Module | Topic | Runs on |
|---|---|---|
| 1–2 | SQL foundations, ClickHouse functions | local + browser |
| 3 | DDL: MergeTree, partitions, ALTER, mutations, ReplacingMergeTree | local |
| 4–6 | Meter readings: cumulative counters, data quality, time series, DST | local |
| 7 | Materialized views, dictionaries, the primary index, big tables | local + browser |
| 8 | Capstone: billing, completeness, leak detection, pipeline table, schema design | local |
| 9 | Big data: 20 billion sensor readings, sort keys, silent read limits | browser |
| 10 | From S3 to dbt: loading files, idempotent loads, dbt models, tests, incremental models | local |

The expected answers are deterministic: everyone who runs `setup.sh` gets the same data, and therefore the same answers.

## What's in the data

`meters.readings` holds 1.95M readings for 300 meters over Q1 2026: 15-minute electricity readings and hourly water readings, stored as cumulative register values in UTC. It deliberately contains real-world problems:

- duplicates and corrected re-sends;
- gaps and two outages;
- two meter replacements (the counter resets to 0);
- a glitch spike;
- readings that arrive up to 5 days late;
- a daylight-saving change (Europe/Sarajevo);
- two water leaks.

The S3 bucket (`s3://meter-raw/readings/YYYY/MM/DD.parquet`) holds the same rows grouped by delivery day, plus one file that was delivered twice.

## Folder layout

```
docker-compose.yml          ClickHouse + S3 (SeaweedFS) + dbt
setup.sh                    one-command setup / reset
.env.example                settings template (setup.sh creates .env)
config/                     ClickHouse named collection for the bucket (credentials come from .env)
init/                       SQL run on the very first start
datasets/
  meters.sql                generates the meters dataset (deterministic)
  lake.sql                  writes the readings to S3 as daily Parquet files
  load_datasets.sql         loads imdb / uk / nyc_taxi
dbt/
  Dockerfile                dbt-core + dbt-clickhouse
  meter_project/            the dbt project you build in module 10
exercises/
  exercises.rb              exercise definitions and reference solutions
  build_expected.rb         runs every reference solution, writes exercises.json
  build_page.rb             builds meter-drills.html from page_template.html + exercises.json
```

## Changing an exercise

Edit `exercises/exercises.rb`, then run:

```bash
ruby exercises/build_expected.rb   # re-runs all 57 reference solutions (local, playground and dbt)
ruby exercises/build_page.rb       # rebuilds exercises/meter-drills.html
```

`build_expected.rb` drops the `practice`, `lake` and `analytics` databases when it finishes, so learners start clean.

## Useful commands

```bash
docker compose stop                 # stop (data is kept)
docker compose start                # start again
docker compose down -v && ./setup.sh   # wipe everything and start fresh
```
