-- Synthetic smart-meter dataset (electricity + water), Q1 2026, fully deterministic.
-- Run:  docker compose exec -T clickhouse clickhouse-client --multiquery < datasets/meters.sql
--
-- What is inside (on purpose, like real AMR/AMI data):
--   * 150 customers (residential / commercial / industrial) in 5 cities
--   * 200 electricity meters (15-min, kWh) + 100 water meters (hourly, m3)
--   * readings.value is a CUMULATIVE register (like the display on the meter), stored in UTC
--   * duplicates (same meter+ts sent twice; some are corrections with a different value)
--   * random missing intervals + outages (meter 17, meter 260)
--   * meter replacements -> counter reset to 0 (meters 42 and 230 on 2026-02-15)
--   * one glitch spike (meter 99)
--   * late-arriving readings (ingested days after the reading time)
--   * DST switch on 2026-03-29 (Europe/Sarajevo local time)
--   * two water leaks starting 2026-03-01 (meters 250 and 277)

-- allow reloading even when your exercise objects (e.g. the exercise 32 dictionary) depend on these tables
SET check_table_dependencies = 0;

CREATE DATABASE IF NOT EXISTS meters;

DROP TABLE IF EXISTS meters.customers;
CREATE TABLE meters.customers
(
    customer_id UInt32,
    name        String,
    segment     LowCardinality(String),
    city        LowCardinality(String),
    signup_date Date
)
ENGINE = MergeTree ORDER BY customer_id;

INSERT INTO meters.customers
SELECT
    number + 1 AS customer_id,
    concat(if(segment = 'residential', 'Household ', if(segment = 'commercial', 'Business ', 'Factory ')), toString(customer_id)) AS name,
    multiIf(customer_id % 10 < 6, 'residential', customer_id % 10 < 9, 'commercial', 'industrial') AS segment,
    ['Sarajevo', 'Banja Luka', 'Tuzla', 'Mostar', 'Zenica'][cityHash64(customer_id, 'city') % 5 + 1] AS city,
    toDate('2018-01-01') + cityHash64(customer_id, 'signup') % 2500 AS signup_date
FROM numbers(150);

DROP TABLE IF EXISTS meters.meters;
CREATE TABLE meters.meters
(
    meter_id         UInt32,
    customer_id      UInt32,
    utility          LowCardinality(String),
    unit             LowCardinality(String),
    interval_minutes UInt8,
    install_date     Date,
    serial           String
)
ENGINE = MergeTree ORDER BY meter_id;

INSERT INTO meters.meters
SELECT
    number + 1 AS meter_id,
    if(meter_id <= 200, (meter_id - 1) % 150 + 1, meter_id - 200) AS customer_id,
    if(meter_id <= 200, 'electricity', 'water') AS utility,
    if(meter_id <= 200, 'kWh', 'm3') AS unit,
    if(meter_id <= 200, 15, 60) AS interval_minutes,
    if(meter_id IN (42, 230), toDate('2026-02-15'), toDate('2019-01-01') + cityHash64(meter_id, 'install') % 2000) AS install_date,
    concat(if(meter_id <= 200, 'EL-', 'WA-'), leftPad(toString(cityHash64(meter_id, if(meter_id IN (42, 230), 'new', 'serial')) % 1000000), 6, '0')) AS serial
FROM numbers(300);

DROP TABLE IF EXISTS meters.tariffs;
CREATE TABLE meters.tariffs
(
    utility    LowCardinality(String),
    segment    LowCardinality(String),
    rate_type  LowCardinality(String),   -- day / night for electricity, flat for water
    from_hour  UInt8,                    -- local time (Europe/Sarajevo), inclusive
    to_hour    UInt8,                    -- local time, exclusive
    price_eur  Decimal(8, 4)             -- per kWh or per m3
)
ENGINE = MergeTree ORDER BY (utility, segment, rate_type);

INSERT INTO meters.tariffs VALUES
    ('electricity', 'residential', 'day',   7, 23, 0.1800), ('electricity', 'residential', 'night', 23, 7, 0.0900),
    ('electricity', 'commercial',  'day',   7, 23, 0.1600), ('electricity', 'commercial',  'night', 23, 7, 0.0800),
    ('electricity', 'industrial',  'day',   7, 23, 0.1300), ('electricity', 'industrial',  'night', 23, 7, 0.0700),
    ('water',       'residential', 'flat',  0, 24, 1.4000),
    ('water',       'commercial',  'flat',  0, 24, 1.6000),
    ('water',       'industrial',  'flat',  0, 24, 1.2000);

DROP TABLE IF EXISTS meters.readings;
CREATE TABLE meters.readings
(
    meter_id    UInt32,
    ts          DateTime('UTC'),          -- end of the measurement interval, UTC
    value       Decimal(12, 3),           -- cumulative register value (kWh or m3)
    ingested_at DateTime('UTC')           -- when our system received it
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (meter_id, ts);

INSERT INTO meters.readings
WITH
    slots AS
    (
        SELECT number % 200 + 1 AS meter_id, toDateTime('2026-01-01 00:00:00', 'UTC') + intDiv(number, 200) * 900 AS ts
        FROM numbers(200 * 96 * 90)
        UNION ALL
        SELECT number % 100 + 201 AS meter_id, toDateTime('2026-01-01 00:00:00', 'UTC') + intDiv(number, 100) * 3600 AS ts
        FROM numbers(100 * 24 * 90)
    ),
    usage AS
    (
        SELECT
            meter_id, ts,
            if(meter_id <= 200, (meter_id - 1) % 150 + 1, meter_id - 200) AS cid,
            multiIf(cid % 10 < 6, 'residential', cid % 10 < 9, 'commercial', 'industrial') AS seg,
            toHour(toTimeZone(ts, 'Europe/Sarajevo')) AS lh,
            toDayOfWeek(toTimeZone(ts, 'Europe/Sarajevo')) AS dow,
            0.6 + (cityHash64(meter_id, 'size') % 1000) / 1000 AS sizef,
            0.8 + (cityHash64(meter_id, toUnixTimestamp(ts), 'noise') % 1000) / 2500 AS noise,
            if(meter_id <= 200,
                multiIf(seg = 'residential', 0.05 + if(lh BETWEEN 6 AND 8, 0.12, 0) + if(lh BETWEEN 18 AND 22, 0.25, 0) + if(dow >= 6 AND lh BETWEEN 9 AND 17, 0.10, 0),
                        seg = 'commercial',  if(dow <= 5 AND lh BETWEEN 8 AND 18, 1.2, 0.25),
                        if(dow <= 5, 4.0, 2.4)),
                multiIf(seg = 'residential', multiIf(lh BETWEEN 6 AND 8, 0.04, lh BETWEEN 18 AND 22, 0.05, lh BETWEEN 0 AND 5, 0, 0.01),
                        seg = 'commercial',  if(dow <= 5 AND lh BETWEEN 8 AND 18, 0.15, 0),
                        if(dow <= 5, 0.6, 0.2))
            ) * sizef * noise
            + if(meter_id IN (250, 277) AND ts >= toDateTime('2026-03-01 00:00:00', 'UTC'), 0.025, 0) AS cons,
            (meter_id IN (42, 230) AND ts >= toDateTime('2026-02-15 00:00:00', 'UTC')) AS replaced,
            if(replaced, 0, round((cityHash64(meter_id, 'start') % 1000000) / if(meter_id <= 200, 20, 500), 3)) AS start_value
        FROM slots
    ),
    cumulative AS
    (
        SELECT
            meter_id, ts,
            toDecimal64(start_value, 3)
              + sum(toDecimal64(round(cons, 3), 3)) OVER (PARTITION BY meter_id, replaced ORDER BY ts ROWS UNBOUNDED PRECEDING) AS true_value
        FROM usage
    )
SELECT
    meter_id,
    ts,
    toDecimal64(
        true_value
        + if(meter_id = 99 AND ts = toDateTime('2026-02-20 12:00:00', 'UTC'), toDecimal64(5000, 3), toDecimal64(0, 3))
        + if(copy = 0 AND d % 1000 = 0, toDecimal64(0.1, 3), toDecimal64(0, 3)), 3) AS value,
    ts + if(cityHash64(meter_id, toUnixTimestamp(ts), 'late') % 300 = 0,
            86400 * (1 + cityHash64(meter_id, toUnixTimestamp(ts), 'days') % 5) + 300,
            300 + cityHash64(meter_id, toUnixTimestamp(ts), 'delay') % 600)
       + copy * 3600 AS ingested_at
FROM (SELECT *, cityHash64(meter_id, toUnixTimestamp(ts), 'dup') AS d FROM cumulative)
ARRAY JOIN if(d % 200 = 0, [0, 1], [0]) AS copy
WHERE cityHash64(meter_id, toUnixTimestamp(ts), 'gap') % 500 != 0
  AND NOT (meter_id = 17  AND ts BETWEEN toDateTime('2026-02-10 00:00:00', 'UTC') AND toDateTime('2026-02-12 23:45:00', 'UTC'))
  AND NOT (meter_id = 260 AND ts BETWEEN toDateTime('2026-03-05 00:00:00', 'UTC') AND toDateTime('2026-03-06 23:00:00', 'UTC'));

OPTIMIZE TABLE meters.readings FINAL;
