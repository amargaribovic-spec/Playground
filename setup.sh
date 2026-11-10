#!/usr/bin/env bash
# One-time setup: creates .env with random passwords, starts ClickHouse + S3, loads every dataset.
# Safe to re-run: datasets are dropped and reloaded, your .env is kept.
# Usage: ./setup.sh            (everything, ~10 min: downloads ~0.5 GB of public datasets)
#        ./setup.sh --no-public (skip imdb / uk / nyc_taxi downloads)
set -euo pipefail
cd "$(dirname "$0")"

rand() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20; }

# Create .env, or add any setting that is missing from an existing one (existing values are kept)
touch .env && chmod 600 .env
ensure() { grep -q "^$1=" .env || { echo "$1=$2" >> .env; echo "  added $1 to .env"; }; }
ensure CLICKHOUSE_USER admin
ensure CLICKHOUSE_PASSWORD "$(rand)"
ensure S3_ACCESS_KEY lake-admin
ensure S3_SECRET_KEY "$(rand)"
set -a; . ./.env; set +a

# Fail early with a clear message if a port is taken (e.g. another ClickHouse is running)
for p in "${CH_HTTP_PORT:-8123}" "${CH_TCP_PORT:-9000}" "${S3_PORT:-8333}"; do
  if lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 && ! docker compose ps --status running -q 2>/dev/null | grep -q .; then
    echo "Port $p is already in use. Stop whatever uses it, or set CH_HTTP_PORT / CH_TCP_PORT / S3_PORT in .env." >&2
    exit 1
  fi
done

# SeaweedFS reads its S3 credentials from a JSON file, generated from .env (git-ignored)
cat > config/s3.json <<EOF
{"identities": [{"name": "lake-admin",
  "credentials": [{"accessKey": "${S3_ACCESS_KEY}", "secretKey": "${S3_SECRET_KEY}"}],
  "actions": ["Admin", "Read", "Write", "List", "Tagging"]}]}
EOF

# Let the ClickHouse user use named collections such as `lake` (user name comes from .env, so this is generated too)
cat > config/users_named_collections.xml <<EOF
<clickhouse><users><${CLICKHOUSE_USER}>
  <named_collection_control>1</named_collection_control>
  <show_named_collections>1</show_named_collections>
</${CLICKHOUSE_USER}></users></clickhouse>
EOF

echo "Starting containers"
docker compose up -d

echo -n "Waiting for ClickHouse"
for _ in $(seq 1 60); do
  if docker compose exec -T clickhouse clickhouse-client -q "SELECT 1" >/dev/null 2>&1; then break; fi
  echo -n "."; sleep 2
done
echo

echo -n "Waiting for S3"
for _ in $(seq 1 60); do
  if docker compose exec -T s3 sh -c 'echo "s3.bucket.list" | weed shell' >/dev/null 2>&1; then break; fi
  echo -n "."; sleep 2
done
echo
docker compose exec -T s3 sh -c 'echo "s3.bucket.create -name meter-raw" | weed shell' >/dev/null 2>&1 || true

ch() { docker compose exec -T clickhouse clickhouse-client --multiquery < "$1"; }

echo "Loading meters dataset (generated, ~10 s)"
ch datasets/meters.sql
echo "Writing meter readings to S3 as daily Parquet files (~10 s)"
ch datasets/lake.sql
if [ "${1:-}" != "--no-public" ]; then
  echo "Loading public datasets imdb, uk, nyc_taxi (downloads from ClickHouse's public bucket, ~10 min)"
  ch datasets/load_datasets.sql
fi

echo "Building the dbt image"
docker compose --profile tools build dbt >/dev/null

echo
echo "Done."
echo "  Web UI:   http://localhost:${CH_HTTP_PORT:-8123}/play   user: ${CLICKHOUSE_USER}   password: see .env"
echo "  Terminal: docker compose exec clickhouse clickhouse-client"
echo "  dbt:      docker compose run --rm dbt build"
