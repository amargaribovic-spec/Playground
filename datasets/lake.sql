-- Writes meters.readings to the local S3 bucket the way a meter head-end system would deliver it:
-- one Parquet file per DELIVERY day (the day we received the rows, from ingested_at), so
--   * late readings show up in a later day's file,
--   * corrected duplicates show up in the file of the day the correction was sent,
--   * one day (2026-03-10) was delivered twice: the original and a "_resend" copy.
-- Layout:  s3://meter-raw/readings/YYYY/MM/DD.parquet   (+ readings/2026/03/10_resend.parquet)
-- Run:  docker compose exec -T clickhouse clickhouse-client --multiquery < datasets/lake.sql

INSERT INTO FUNCTION s3(lake, filename = 'readings/{_partition_id}.parquet', format = 'Parquet')
PARTITION BY formatDateTime(ingested_at, '%Y/%m/%d')
SELECT meter_id, ts, value, ingested_at
FROM meters.readings
ORDER BY meter_id, ts
SETTINGS s3_truncate_on_insert = 1;

INSERT INTO FUNCTION s3(lake, filename = 'readings/2026/03/10_resend.parquet', format = 'Parquet')
SELECT * FROM s3(lake, filename = 'readings/2026/03/10.parquet', format = 'Parquet')
SETTINGS s3_truncate_on_insert = 1;
