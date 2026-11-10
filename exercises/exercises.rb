# Exercise definitions for the ClickHouse training page.
# Each exercise: id, mod, title, where (local|browser), data, skills, task (HTML), hint,
#   solution (reference SQL, shown on demand), check (auto|review),
#   setup (optional SQL run before verify), verify (SQL whose output is the expected result;
#   defaults to solution).

MODULES = [
  { id: 1, name: 'SQL foundations', blurb: 'Filtering, grouping, joins and sorting on familiar datasets.' },
  { id: 2, name: 'ClickHouse functions', blurb: 'Quantiles, argMax, conditional aggregates, arrays and date functions.' },
  { id: 3, name: 'DDL and data modeling', blurb: 'MergeTree tables, partitions, ALTERs, mutations and deduplicating engines.' },
  { id: 4, name: 'Meter readings basics', blurb: 'Turn cumulative register values into consumption.' },
  { id: 5, name: 'Data quality', blurb: 'Duplicates, gaps, counter resets, spikes and late data.' },
  { id: 6, name: 'Time series', blurb: 'Local time and DST, WITH FILL, rolling windows, period comparisons, peak demand.' },
  { id: 7, name: 'Performance and big data', blurb: 'Materialized views, dictionaries, the primary index and billion-row tables.' },
  { id: 8, name: 'Capstone', blurb: 'Project-style tasks that combine everything: billing, completeness, leaks, pipelines.' },
  { id: 9, name: 'Big data in the browser', blurb: 'Billions of rows on sql.clickhouse.com: sensor fleets, sort keys, silent limits and data quality at scale. Do these after module 5 or any time you want a change of pace.' },
  { id: 10, name: 'From S3 to dbt', blurb: 'The project pipeline on your machine: raw Parquet files in an S3 bucket, loaded into ClickHouse, transformed and tested with dbt. Do it after module 8.' },
]

EXERCISES = []
def ex(h)
  EXERCISES << h
end

# ---------------------------------------------------------------- Module 1
ex id: 1, mod: 1, title: 'Movies per decade', where: 'local', data: 'imdb.movies', skills: %w[GROUP\ BY intDiv],
   task: 'Count the movies released in each decade from 1950 to 1999. A decade is the year rounded down to a multiple of 10 (1950, 1960 …).',
   cols: 'decade, movies', order: 'decade ascending',
   hint: 'intDiv(year, 10) * 10 gives the decade.',
   solution: <<~'SQL'
     SELECT intDiv(year, 10) * 10 AS decade, count() AS movies
     FROM imdb.movies
     WHERE year BETWEEN 1950 AND 1999
     GROUP BY decade
     ORDER BY decade
   SQL

ex id: 2, mod: 1, title: 'Busiest towns in 2022', where: 'local', data: 'uk.uk_price_paid', skills: %w[WHERE GROUP\ BY LIMIT],
   task: 'Find the 5 towns with the most property sales in 2022.',
   cols: 'town, sales', order: 'sales descending, then town',
   hint: 'toYear(date) = 2022, then ORDER BY sales DESC LIMIT 5.',
   solution: <<~'SQL'
     SELECT town, count() AS sales
     FROM uk.uk_price_paid
     WHERE toYear(date) = 2022
     GROUP BY town
     ORDER BY sales DESC, town
     LIMIT 5
   SQL

ex id: 3, mod: 1, title: 'Top genres since 2000', where: 'local', data: 'imdb.movies + imdb.movies_genres', skills: %w[JOIN GROUP\ BY],
   task: 'Join movies to their genres and find the 5 genres with the most movies released in 2000 or later.',
   cols: 'genre, movies', order: 'movies descending, then genre',
   hint: 'movies_genres.movie_id = movies.id',
   solution: <<~'SQL'
     SELECT g.genre, count() AS movies
     FROM imdb.movies_genres AS g
     INNER JOIN imdb.movies AS m ON m.id = g.movie_id
     WHERE m.year >= 2000
     GROUP BY g.genre
     ORDER BY movies DESC, g.genre
     LIMIT 5
   SQL

ex id: 4, mod: 1, title: 'Most active Hacker News authors', where: 'browser', data: 'hackernews.hackernews', skills: %w[WHERE GROUP\ BY avg],
   task: 'Run this one in the browser playground. Find the 5 authors (column <code>by</code>) who posted the most stories in 2020, with their average story score. Only count rows where <code>type = \'story\'</code> and the author is not empty.',
   cols: 'author, stories, avg_score (rounded to 2 decimals)', order: 'stories descending, then author',
   hint: '`by` is a reserved word in SQL, so quote it with backticks or alias it.',
   solution: <<~'SQL'
     SELECT `by` AS author, count() AS stories, round(avg(score), 2) AS avg_score
     FROM hackernews.hackernews
     WHERE type = 'story' AND toYear(time) = 2020 AND `by` != ''
     GROUP BY author
     ORDER BY stories DESC, author
     LIMIT 5
   SQL

ex id: 5, mod: 1, title: 'Airlines with the most flights', where: 'browser', data: 'ontime.ontime', skills: %w[GROUP\ BY avg],
   task: 'Run this one in the browser playground. For 2019, find the 5 airlines (<code>Reporting_Airline</code>) with the most flights (all rows), and the average arrival delay (<code>ArrDelay</code>) of their flights that were neither cancelled nor diverted. A cancelled flight has <code>ArrDelay = 0</code>, so leaving those rows in would make airlines look more punctual than they are.',
   cols: 'airline, flights, avg_arr_delay (rounded to 2 decimals)', order: 'flights descending',
   hint: 'Filter on Year, the first column of the table\'s sort key, so ClickHouse skips the other years. avgIf(ArrDelay, Cancelled = 0 AND Diverted = 0) averages only the flights that arrived.',
   solution: <<~'SQL'
     SELECT Reporting_Airline AS airline, count() AS flights,
            round(avgIf(ArrDelay, Cancelled = 0 AND Diverted = 0), 2) AS avg_arr_delay
     FROM ontime.ontime
     WHERE Year = 2019
     GROUP BY airline
     ORDER BY flights DESC
     LIMIT 5
   SQL

# ---------------------------------------------------------------- Module 2
ex id: 6, mod: 2, title: 'Median London price', where: 'local', data: 'uk.uk_price_paid', skills: %w[quantileExact],
   task: 'For town <code>LONDON</code>, return the exact median sale price for each year from 2018 to 2022.',
   cols: 'year, median_price', order: 'year ascending',
   hint: 'median() is approximate. Use quantileExact(0.5)(price) to get the exact value.',
   solution: <<~'SQL'
     SELECT toYear(date) AS year, quantileExact(0.5)(price) AS median_price
     FROM uk.uk_price_paid
     WHERE town = 'LONDON' AND year BETWEEN 2018 AND 2022
     GROUP BY year
     ORDER BY year
   SQL

ex id: 7, mod: 2, title: 'Most expensive street per year', where: 'local', data: 'uk.uk_price_paid', skills: %w[argMax max],
   task: 'For town <code>MANCHESTER</code>, show each year from 2019 to 2022 with the highest sale price and the street of that sale, without a JOIN or subquery.',
   cols: 'year, max_price, street', order: 'year ascending',
   hint: 'argMax(street, price) returns the street of the row with the highest price.',
   solution: <<~'SQL'
     SELECT toYear(date) AS year, max(price) AS max_price, argMax(street, price) AS street
     FROM uk.uk_price_paid
     WHERE town = 'MANCHESTER' AND year BETWEEN 2019 AND 2022
     GROUP BY year
     ORDER BY year
   SQL

ex id: 8, mod: 2, title: 'Taxi trips by weekday', where: 'local', data: 'nyc_taxi.trips', skills: %w[toDayOfWeek countIf],
   task: 'For every day of the week (1 = Monday … 7 = Sunday), return the number of trips, the average trip distance and the percentage of trips paid by card (<code>payment_type = \'CRE\'</code>).',
   cols: 'day_of_week, trips, avg_distance, card_pct (both rounded to 2 decimals)', order: 'day_of_week ascending',
   hint: 'countIf(condition) counts only the matching rows, so you don\'t need a CASE inside sum().',
   solution: <<~'SQL'
     SELECT
         toDayOfWeek(pickup_datetime) AS day_of_week,
         count() AS trips,
         round(avg(trip_distance), 2) AS avg_distance,
         round(countIf(payment_type = 'CRE') / count() * 100, 2) AS card_pct
     FROM nyc_taxi.trips
     GROUP BY day_of_week
     ORDER BY day_of_week
   SQL

ex id: 9, mod: 2, title: 'COVID in Bosnia and Herzegovina', where: 'browser', data: 'covid.covid19', skills: %w[sum toYear],
   task: 'Run this one in the browser playground. For <code>location_key = \'BA\'</code>, sum new confirmed cases and new deaths per year.',
   cols: 'year, confirmed, deceased', order: 'year ascending',
   hint: 'The new_* columns are daily values; the cumulative_* columns are running totals. Sum the daily ones.',
   solution: <<~'SQL'
     SELECT toYear(date) AS year, sum(new_confirmed) AS confirmed, sum(new_deceased) AS deceased
     FROM covid.covid19
     WHERE location_key = 'BA'
     GROUP BY year
     ORDER BY year
   SQL

ex id: 10, mod: 2, title: 'Genres as one string', where: 'local', data: 'imdb.movies + imdb.movies_genres', skills: %w[groupArray arraySort arrayStringConcat],
   task: 'For the movies with ids 267038 (Pulp Fiction), 207992 (The Matrix) and 333856 (Titanic, 1997), return each movie\'s genres as one alphabetically sorted, comma-separated string, for example <code>Crime, Drama</code>.',
   cols: 'name, year, genres', order: 'year, then name',
   hint: "groupArray collects values into an array, arraySort sorts it, and arrayStringConcat(arr, ', ') joins it.",
   solution: <<~'SQL'
     SELECT m.name, m.year, arrayStringConcat(arraySort(groupArray(g.genre)), ', ') AS genres
     FROM imdb.movies AS m
     INNER JOIN imdb.movies_genres AS g ON g.movie_id = m.id
     WHERE m.id IN (267038, 207992, 333856)
     GROUP BY m.name, m.year
     ORDER BY m.year, m.name
   SQL

# ---------------------------------------------------------------- Module 3 (practice database, run in order)
ex id: 11, mod: 3, title: 'Partitioned readings table', where: 'local', data: 'meters.readings → practice', skills: %w[CREATE\ TABLE MergeTree PARTITION\ BY],
   task: 'Create a database <code>practice</code> and a table <code>practice.readings_m</code> with the same columns as <code>meters.readings</code>. Use the MergeTree engine, partition it by month (<code>toYYYYMM(ts)</code>) and order it by <code>(meter_id, ts)</code>. Insert all readings of meters 1 to 10. Then run the check query and paste its result.',
   verify_note: true,
   cols: 'partition, rows', order: 'partition',
   hint: 'Write the CREATE TABLE yourself; don\'t use CREATE TABLE … AS. Run SHOW CREATE TABLE meters.readings if you need a reference.',
   setup: <<~'SQL',
     DROP DATABASE IF EXISTS practice;
     CREATE DATABASE practice;
     CREATE TABLE practice.readings_m
     (
         meter_id    UInt32,
         ts          DateTime('UTC'),
         value       Decimal(12, 3),
         ingested_at DateTime('UTC')
     )
     ENGINE = MergeTree
     PARTITION BY toYYYYMM(ts)
     ORDER BY (meter_id, ts);
     INSERT INTO practice.readings_m SELECT * FROM meters.readings WHERE meter_id BETWEEN 1 AND 10;
   SQL
   verify: <<~'SQL'
     SELECT partition, sum(rows) AS rows
     FROM system.parts
     WHERE database = 'practice' AND table = 'readings_m' AND active
     GROUP BY partition
     ORDER BY partition
   SQL

ex id: 12, mod: 3, title: 'Materialized local date', where: 'local', data: 'practice.readings_m', skills: %w[ALTER\ ADD\ COLUMN MATERIALIZED toDate\ with\ timezone],
   task: 'Add a column <code>local_date Date</code> to <code>practice.readings_m</code> that ClickHouse computes automatically as the reading\'s date in the <code>Europe/Sarajevo</code> time zone. Then fill it for the existing rows. Run the check query and paste its result. The 29th has 4 readings fewer (one hour) because the clocks move forward that night.',
   verify_note: true,
   cols: 'local_date, readings', order: 'local_date',
   hint: 'ADD COLUMN … MATERIALIZED toDate(ts, \'Europe/Sarajevo\'), then ALTER TABLE … MATERIALIZE COLUMN local_date.',
   setup: <<~'SQL',
     ALTER TABLE practice.readings_m ADD COLUMN local_date Date MATERIALIZED toDate(ts, 'Europe/Sarajevo');
     ALTER TABLE practice.readings_m MATERIALIZE COLUMN local_date SETTINGS mutations_sync = 1;
   SQL
   verify: <<~'SQL'
     SELECT local_date, count() AS readings
     FROM practice.readings_m
     WHERE meter_id = 6 AND local_date BETWEEN '2026-03-28' AND '2026-03-30'
     GROUP BY local_date
     ORDER BY local_date
   SQL

ex id: 13, mod: 3, title: 'Drop a month', where: 'local', data: 'practice.readings_m', skills: %w[DROP\ PARTITION],
   task: 'The January data has to be reloaded. Remove all of January 2026 from <code>practice.readings_m</code> in one instant operation, without using DELETE. Run the check query and paste its result.',
   verify_note: true,
   cols: 'first_ts, rows', order: '-',
   hint: 'ALTER TABLE … DROP PARTITION <partition id>. Exercise 11 showed you the partition ids.',
   setup: <<~'SQL',
     ALTER TABLE practice.readings_m DROP PARTITION 202601;
   SQL
   verify: <<~'SQL'
     SELECT min(ts) AS first_ts, count() AS rows
     FROM practice.readings_m
   SQL

ex id: 14, mod: 3, title: 'Delete and update rows', where: 'local', data: 'practice.readings_m', skills: %w[DELETE ALTER\ UPDATE mutations],
   task: 'Do two fixes on <code>practice.readings_m</code>: (1) delete all readings of meter 5 on the UTC date 2026-02-01; (2) every reading that arrived more than 1 day late should get <code>ingested_at = ts + 10 minutes</code>. Run the check query and paste its result.',
   verify_note: true,
   cols: 'meter5_feb1_left, late_left, rows', order: '-',
   hint: 'Use a lightweight DELETE FROM … WHERE for the delete and ALTER TABLE … UPDATE … WHERE for the update. Check system.mutations to see when the update has finished.',
   setup: <<~'SQL',
     DELETE FROM practice.readings_m WHERE meter_id = 5 AND toDate(ts) = '2026-02-01';
     ALTER TABLE practice.readings_m UPDATE ingested_at = ts + INTERVAL 10 MINUTE WHERE ingested_at > ts + INTERVAL 1 DAY SETTINGS mutations_sync = 1;
   SQL
   verify: <<~'SQL'
     SELECT
         countIf(meter_id = 5 AND toDate(ts) = '2026-02-01') AS meter5_feb1_left,
         countIf(ingested_at > ts + INTERVAL 1 DAY) AS late_left,
         count() AS rows
     FROM practice.readings_m
   SQL

ex id: 15, mod: 3, title: 'Deduplicating table', where: 'local', data: 'meters.readings → practice', skills: %w[ReplacingMergeTree FINAL],
   task: 'The meter feed sometimes sends the same reading twice, and the later copy is the correct one. Create <code>practice.readings_dedup</code> with an engine that keeps only the row with the newest <code>ingested_at</code> for each <code>(meter_id, ts)</code>. Insert all of <code>meters.readings</code> into it. Run the check query and paste its result.',
   verify_note: true,
   cols: 'rows, total_value', order: '-',
   hint: 'ReplacingMergeTree(ingested_at) ORDER BY (meter_id, ts). Merges happen in the background, so read with FINAL to get exact results.',
   setup: <<~'SQL',
     CREATE TABLE practice.readings_dedup
     (
         meter_id    UInt32,
         ts          DateTime('UTC'),
         value       Decimal(12, 3),
         ingested_at DateTime('UTC')
     )
     ENGINE = ReplacingMergeTree(ingested_at)
     PARTITION BY toYYYYMM(ts)
     ORDER BY (meter_id, ts);
     INSERT INTO practice.readings_dedup SELECT * FROM meters.readings;
   SQL
   verify: <<~'SQL'
     SELECT count() AS rows, sum(value) AS total_value
     FROM practice.readings_dedup FINAL
   SQL

# ---------------------------------------------------------------- Module 4
ex id: 16, mod: 4, title: 'Dataset inventory', where: 'local', data: 'meters.readings + meters.meters', skills: %w[JOIN uniqExact min/max],
   task: 'Start every new dataset with an overview. Per utility, return the number of meters that sent readings, the number of reading rows, and the first and last reading time.',
   cols: 'utility, meters, readings, first_ts, last_ts', order: 'utility',
   hint: 'Join readings to meters on meter_id, then use uniqExact(meter_id), count(), min(ts) and max(ts).',
   solution: <<~'SQL'
     SELECT m.utility, uniqExact(r.meter_id) AS meters, count() AS readings, min(r.ts) AS first_ts, max(r.ts) AS last_ts
     FROM meters.readings AS r
     INNER JOIN meters.meters AS m ON m.meter_id = r.meter_id
     GROUP BY m.utility
     ORDER BY m.utility
   SQL

ex id: 17, mod: 4, title: 'Daily consumption of one meter', where: 'local', data: 'meters.readings', skills: %w[argMax lagInFrame],
   task: 'A day\'s consumption is the last register value of that day minus the last register value of the previous day. For meter 1, return the consumption of each UTC day from 2026-01-05 to 2026-01-11. If a timestamp has several rows, use the one with the newest <code>ingested_at</code>.',
   cols: 'day, kwh', order: 'day',
   hint: 'argMax(value, (ts, ingested_at)) gives the last value of the day. Include January 4 in the inner query so January 5 has a previous day, and filter it out at the end. On the first row, lagInFrame returns 0 rather than NULL, so January 4 would show the whole register value; that is another reason to drop it.',
   solution: <<~'SQL'
     SELECT day, kwh
     FROM
     (
         SELECT day, day_end - lagInFrame(day_end) OVER (ORDER BY day) AS kwh
         FROM
         (
             SELECT toDate(ts) AS day, argMax(value, (ts, ingested_at)) AS day_end
             FROM meters.readings
             WHERE meter_id = 1 AND ts >= '2026-01-04' AND ts < '2026-01-12'
             GROUP BY day
         )
     )
     WHERE day >= '2026-01-05'
     ORDER BY day
   SQL

ex id: 18, mod: 4, title: 'Monthly consumption per utility', where: 'local', data: 'meters.readings + meters.meters', skills: %w[two-level\ aggregation],
   task: 'Use the simple method: for each meter and each UTC month, consumption = <code>max(value) − min(value)</code>. Then sum the meters per utility. Use the raw readings (no deduplication) and leave out meters 42, 99 and 230, which have known problems you will handle in module 5.',
   cols: 'month (first day of the month, e.g. 2026-01-01), utility, consumption (rounded to 2 decimals)', order: 'month, then utility',
   hint: 'Aggregate per (month, meter_id) in a subquery, then join to meters.meters and aggregate again per (month, utility).',
   solution: <<~'SQL'
     SELECT t.month, m.utility, round(sum(t.consumption), 2) AS consumption
     FROM
     (
         SELECT toStartOfMonth(ts) AS month, meter_id, max(value) - min(value) AS consumption
         FROM meters.readings
         WHERE meter_id NOT IN (42, 99, 230)
         GROUP BY month, meter_id
     ) AS t
     INNER JOIN meters.meters AS m ON m.meter_id = t.meter_id
     GROUP BY t.month, m.utility
     ORDER BY t.month, m.utility
   SQL

ex id: 19, mod: 4, title: 'Top electricity customers', where: 'local', data: 'readings + meters + customers', skills: %w[multi-JOIN],
   task: 'Find the 5 customers who used the most electricity in February 2026 (UTC). Use the same <code>max − min</code> method per meter, add up all of a customer\'s electricity meters, and leave out meters 42, 99 and 230.',
   cols: 'customer_id, name, kwh (rounded to 2 decimals)', order: 'kwh descending',
   hint: 'Some customers have two electricity meters, so add them up per customer.',
   solution: <<~'SQL'
     SELECT c.customer_id AS customer_id, c.name AS name, round(sum(t.kwh), 2) AS kwh
     FROM
     (
         SELECT meter_id, max(value) - min(value) AS kwh
         FROM meters.readings
         WHERE ts >= '2026-02-01' AND ts < '2026-03-01' AND meter_id NOT IN (42, 99, 230)
         GROUP BY meter_id
     ) AS t
     INNER JOIN meters.meters AS m ON m.meter_id = t.meter_id
     INNER JOIN meters.customers AS c ON c.customer_id = m.customer_id
     WHERE m.utility = 'electricity'
     GROUP BY c.customer_id, c.name
     ORDER BY kwh DESC
     LIMIT 5
   SQL

ex id: 20, mod: 4, title: 'Day and night load profile', where: 'local', data: 'readings + meters + customers', skills: %w[window\ functions avgIf time-of-use],
   task: 'Tariffs charge more during the day (07:00–22:59 local time) than at night, so the team wants to know how differently each customer segment uses electricity. Using January 2026 electricity data (<code>ts &lt; \'2026-02-01\'</code>, UTC), return per segment the average 15-minute consumption in day hours and in night hours, and the day/night ratio. Remove duplicates first (keep the newest <code>ingested_at</code>). Interval consumption = value − the previous reading\'s value, even across a gap. A reading counts as day when the local hour (Europe/Sarajevo) of its <code>ts</code> is 7 to 22. Skip each meter\'s first reading, and leave out meters 42, 99 and 230.',
   cols: 'segment, day_avg_kwh, night_avg_kwh (both rounded to 3 decimals), day_night_ratio (rounded to 2 decimals, calculated from the unrounded averages)', order: 'segment',
   hint: 'Build it in steps: dedup with GROUP BY meter_id, ts + argMax(value, ingested_at); then lagInFrame and row_number OVER (PARTITION BY meter_id ORDER BY ts); then avgIf(kwh, local_hour BETWEEN 7 AND 22) and avgIf(kwh, NOT …) per segment.',
   solution: <<~'SQL'
     WITH
         dedup AS
         (
             SELECT meter_id, ts, argMax(value, ingested_at) AS value
             FROM meters.readings
             WHERE meter_id <= 200 AND meter_id NOT IN (42, 99, 230) AND ts < '2026-02-01'
             GROUP BY meter_id, ts
         ),
         deltas AS
         (
             SELECT meter_id, ts,
                    value - lagInFrame(value) OVER w AS kwh,
                    row_number() OVER w AS rn
             FROM dedup
             WINDOW w AS (PARTITION BY meter_id ORDER BY ts)
         ),
         profile AS
         (
             SELECT c.segment AS segment,
                    avgIf(d.kwh, toHour(toTimeZone(d.ts, 'Europe/Sarajevo')) BETWEEN 7 AND 22) AS day_avg,
                    avgIf(d.kwh, NOT (toHour(toTimeZone(d.ts, 'Europe/Sarajevo')) BETWEEN 7 AND 22)) AS night_avg
             FROM deltas AS d
             INNER JOIN meters.meters AS m ON m.meter_id = d.meter_id
             INNER JOIN meters.customers AS c ON c.customer_id = m.customer_id
             WHERE d.rn > 1
             GROUP BY c.segment
         )
     SELECT segment,
            round(day_avg, 3) AS day_avg_kwh,
            round(night_avg, 3) AS night_avg_kwh,
            round(day_avg / night_avg, 2) AS day_night_ratio
     FROM profile
     ORDER BY segment
   SQL

# ---------------------------------------------------------------- Module 5
ex id: 21, mod: 5, title: 'Find duplicates', where: 'local', data: 'meters.readings', skills: %w[HAVING uniqExact],
   task: 'Per utility, count the duplicate keys (a <code>(meter_id, ts)</code> with more than one row) and how many of them are conflicting (the copies have different values).',
   cols: 'utility, duplicate_keys, conflicting_keys', order: 'utility',
   hint: 'GROUP BY meter_id, ts HAVING count() > 1, with uniqExact(value) to spot conflicts, then join to meters.',
   solution: <<~'SQL'
     SELECT m.utility, count() AS duplicate_keys, countIf(d.distinct_values > 1) AS conflicting_keys
     FROM
     (
         SELECT meter_id, ts, uniqExact(value) AS distinct_values
         FROM meters.readings
         GROUP BY meter_id, ts
         HAVING count() > 1
     ) AS d
     INNER JOIN meters.meters AS m ON m.meter_id = d.meter_id
     GROUP BY m.utility
     ORDER BY m.utility
   SQL

ex id: 22, mod: 5, title: 'Missing intervals', where: 'local', data: 'meters.readings + meters.meters', skills: %w[completeness],
   task: 'Each electricity meter should have 8,640 distinct timestamps in Q1 (90 days × 96), and each water meter 2,160 (90 × 24). Return the 5 meters with the most missing timestamps.',
   cols: 'meter_id, utility, expected, received, missing', order: 'missing descending, then meter_id',
   hint: 'Count received timestamps with uniqExact(ts) so duplicates don\'t count twice.',
   solution: <<~'SQL'
     SELECT r.meter_id, m.utility,
            if(m.utility = 'electricity', 8640, 2160) AS expected,
            uniqExact(r.ts) AS received,
            expected - received AS missing
     FROM meters.readings AS r
     INNER JOIN meters.meters AS m ON m.meter_id = r.meter_id
     GROUP BY r.meter_id, m.utility
     ORDER BY missing DESC, r.meter_id
     LIMIT 5
   SQL

ex id: 23, mod: 5, title: 'Counter going backwards', where: 'local', data: 'meters.readings', skills: %w[lagInFrame dedup],
   task: 'A cumulative register should never go down. After deduplicating (keep the newest <code>ingested_at</code>), list every reading whose value is lower than the meter\'s previous reading.',
   cols: 'meter_id, ts, prev_value, value', order: 'meter_id, ts',
   hint: 'Without deduplication you get false alarms from the conflicting copies. Skip each meter\'s first row (row_number() > 1).',
   solution: <<~'SQL'
     WITH dedup AS
     (
         SELECT meter_id, ts, argMax(value, ingested_at) AS value
         FROM meters.readings
         GROUP BY meter_id, ts
     )
     SELECT meter_id, ts, prev_value, value
     FROM
     (
         SELECT meter_id, ts, value,
                lagInFrame(value) OVER w AS prev_value,
                row_number() OVER w AS rn
         FROM dedup
         WINDOW w AS (PARTITION BY meter_id ORDER BY ts)
     )
     WHERE rn > 1 AND value < prev_value
     ORDER BY meter_id, ts
   SQL

ex id: 24, mod: 5, title: 'Spike detection', where: 'local', data: 'meters.readings', skills: %w[quantileExact rate\ normalization],
   task: 'Find electricity spikes. After deduplicating, compute each interval\'s consumption rate in kWh per hour: <code>(value − prev_value) / minutes since the previous reading × 60</code>. Ignore negative deltas. A spike is a rate more than 20 times that meter\'s median rate. Dividing by the minutes stops a gap, such as a 3-day outage, from looking like a spike.',
   cols: 'meter_id, ts, delta', order: 'meter_id, ts',
   hint: 'Calculate the median per meter in a separate CTE and join it back. Convert to Float64 before dividing.',
   solution: <<~'SQL'
     WITH
         dedup AS
         (
             SELECT meter_id, ts, argMax(value, ingested_at) AS value
             FROM meters.readings
             WHERE meter_id <= 200
             GROUP BY meter_id, ts
         ),
         d AS
         (
             SELECT meter_id, ts,
                    value - lagInFrame(value) OVER w AS delta,
                    dateDiff('minute', lagInFrame(ts) OVER w, ts) AS minutes,
                    row_number() OVER w AS rn
             FROM dedup
             WINDOW w AS (PARTITION BY meter_id ORDER BY ts)
         ),
         rates AS
         (
             SELECT meter_id, ts, delta, toFloat64(delta) / minutes * 60 AS rate
             FROM d
             WHERE rn > 1 AND delta >= 0
         ),
         med AS
         (
             SELECT meter_id, quantileExact(0.5)(rate) AS median_rate
             FROM rates
             GROUP BY meter_id
         )
     SELECT r.meter_id, r.ts, r.delta
     FROM rates AS r
     INNER JOIN med ON med.meter_id = r.meter_id
     WHERE r.rate > 20 * med.median_rate
     ORDER BY r.meter_id, r.ts
   SQL

ex id: 25, mod: 5, title: 'Late arrivals', where: 'local', data: 'meters.readings', skills: %w[countIf INTERVAL],
   task: 'Per UTC month, count all reading rows, the rows that arrived more than 1 day after their timestamp, and the late share as a percentage.',
   cols: 'month (first day of the month, e.g. 2026-01-01), readings, late, late_pct (rounded to 2 decimals)', order: 'month',
   hint: 'ingested_at > ts + INTERVAL 1 DAY',
   solution: <<~'SQL'
     SELECT toStartOfMonth(ts) AS month,
            count() AS readings,
            countIf(ingested_at > ts + INTERVAL 1 DAY) AS late,
            round(late / readings * 100, 2) AS late_pct
     FROM meters.readings
     GROUP BY month
     ORDER BY month
   SQL

# ---------------------------------------------------------------- Module 6
ex id: 26, mod: 6, title: 'Daylight-saving day', where: 'local', data: 'meters.readings', skills: %w[time\ zones DST],
   task: 'Readings are stored in UTC, but customers are billed by local days. For meter 6, count the distinct readings per local date (Europe/Sarajevo) for 2026-03-28, 03-29 and 03-30. On the 29th the clocks move forward, so that day has only 23 hours: 92 fifteen-minute readings instead of 96.',
   cols: 'local_date, readings', order: 'local_date',
   hint: 'toDate(ts, \'Europe/Sarajevo\'), and uniqExact(ts) so duplicates don\'t count twice.',
   solution: <<~'SQL'
     SELECT toDate(ts, 'Europe/Sarajevo') AS local_date, uniqExact(ts) AS readings
     FROM meters.readings
     WHERE meter_id = 6 AND local_date BETWEEN '2026-03-28' AND '2026-03-30'
     GROUP BY local_date
     ORDER BY local_date
   SQL

ex id: 27, mod: 6, title: 'Show the outage', where: 'local', data: 'meters.readings', skills: %w[WITH\ FILL],
   task: 'Meter 17 had an outage. Count its distinct readings per UTC day from 2026-02-08 to 2026-02-14. Days without readings must still appear, with 0. Let ClickHouse fill them in; don\'t build a calendar table.',
   cols: 'day, readings', order: 'day',
   hint: 'ORDER BY day WITH FILL FROM toDate(\'2026-02-08\') TO toDate(\'2026-02-15\')',
   solution: <<~'SQL'
     SELECT toDate(ts) AS day, uniqExact(ts) AS readings
     FROM meters.readings
     WHERE meter_id = 17 AND ts >= '2026-02-08' AND ts < '2026-02-15'
     GROUP BY day
     ORDER BY day WITH FILL FROM toDate('2026-02-08') TO toDate('2026-02-15')
   SQL

ex id: 28, mod: 6, title: '7-day rolling average', where: 'local', data: 'meters.readings', skills: %w[window\ frame ROWS\ BETWEEN],
   task: 'For meter 3, calculate daily UTC consumption with the method from exercise 17 (last value of the day minus last value of the previous day). Add a 7-day rolling average: the current day and the 6 days before it. Return 2026-03-25 to 2026-03-31.',
   cols: 'day, kwh, avg_7d (both rounded to 2 decimals)', order: 'day',
   hint: 'Calculate the window before you filter to Mar 25–31, or the first days will average fewer than 7 values. avg(kwh) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)',
   solution: <<~'SQL'
     WITH
         daily AS
         (
             SELECT toDate(ts) AS day, argMax(value, (ts, ingested_at)) AS day_end
             FROM meters.readings
             WHERE meter_id = 3 AND ts >= '2026-03-17'
             GROUP BY day
         ),
         cons AS
         (
             SELECT day, day_end - lagInFrame(day_end) OVER (ORDER BY day) AS kwh
             FROM daily
         )
     SELECT day, round(kwh, 2) AS kwh, round(avg_7d, 2) AS avg_7d
     FROM
     (
         SELECT day, kwh, avg(kwh) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS avg_7d
         FROM cons
         WHERE day >= '2026-03-18'
     )
     WHERE day >= '2026-03-25'
     ORDER BY day
   SQL

ex id: 29, mod: 6, title: 'Month-over-month change', where: 'local', data: 'readings + meters + customers', skills: %w[lagInFrame NULL\ handling],
   task: 'Using the <code>max − min</code> method per meter and UTC month (electricity only, leaving out meters 42, 99 and 230), sum consumption per segment and month, then add the percentage change from the previous month. January has no previous month, so its change must be NULL, not 0 or infinity.',
   cols: 'segment, month (first day of the month, e.g. 2026-01-01), kwh, mom_pct (both rounded to 2 decimals)', order: 'segment, month',
   hint: 'lagInFrame(toNullable(kwh)) OVER (PARTITION BY segment ORDER BY month) returns NULL on the first row. Convert to Float64 before dividing: Decimal division keeps only the input scale (3 decimals), so it would give &minus;9.3 instead of &minus;9.36.',
   solution: <<~'SQL'
     WITH monthly AS
     (
         SELECT c.segment, t.month, toFloat64(sum(t.kwh)) AS kwh
         FROM
         (
             SELECT meter_id, toStartOfMonth(ts) AS month, max(value) - min(value) AS kwh
             FROM meters.readings
             WHERE meter_id <= 200 AND meter_id NOT IN (42, 99, 230)
             GROUP BY meter_id, month
         ) AS t
         INNER JOIN meters.meters AS m ON m.meter_id = t.meter_id
         INNER JOIN meters.customers AS c ON c.customer_id = m.customer_id
         GROUP BY c.segment, t.month
     )
     SELECT segment, month, round(kwh, 2) AS kwh,
            round((kwh - prev) / prev * 100, 2) AS mom_pct
     FROM
     (
         SELECT segment, month, kwh,
                lagInFrame(toNullable(kwh)) OVER (PARTITION BY segment ORDER BY month) AS prev
         FROM monthly
     )
     ORDER BY segment, month
   SQL

ex id: 30, mod: 6, title: 'Peak demand', where: 'local', data: 'meters.readings', skills: %w[demand\ kW argMax],
   task: 'Peak demand in kW is the highest 15-minute consumption × 4. For January 2026 electricity (<code>ts &lt; \'2026-02-01\'</code>, UTC; deduplicated; leaving out meters 42, 99 and 230), use only intervals whose previous reading is exactly 15 minutes earlier. Return the 5 meters with the highest peak and when the peak happened. If a meter reaches its peak more than once, report the latest time.',
   cols: 'meter_id, peak_kw (rounded to 2 decimals), peak_ts', order: 'peak_kw descending',
   hint: 'dateDiff(\'minute\', lagInFrame(ts) OVER w, ts) = 15 removes intervals that span a gap. argMax(ts, (kwh, ts)) breaks ties by picking the latest ts.',
   solution: <<~'SQL'
     WITH
         dedup AS
         (
             SELECT meter_id, ts, argMax(value, ingested_at) AS value
             FROM meters.readings
             WHERE meter_id <= 200 AND meter_id NOT IN (42, 99, 230) AND ts < '2026-02-01'
             GROUP BY meter_id, ts
         ),
         d AS
         (
             SELECT meter_id, ts,
                    value - lagInFrame(value) OVER w AS kwh,
                    dateDiff('minute', lagInFrame(ts) OVER w, ts) AS minutes,
                    row_number() OVER w AS rn
             FROM dedup
             WINDOW w AS (PARTITION BY meter_id ORDER BY ts)
         )
     SELECT meter_id, round(max(kwh * 4), 2) AS peak_kw, argMax(ts, (kwh, ts)) AS peak_ts
     FROM d
     WHERE rn > 1 AND minutes = 15
     GROUP BY meter_id
     ORDER BY peak_kw DESC
     LIMIT 5
   SQL

# ---------------------------------------------------------------- Module 7
ex id: 31, mod: 7, title: 'Materialized view', where: 'local', data: 'meters.readings → practice', skills: %w[MATERIALIZED\ VIEW AggregatingMergeTree -State/-Merge],
   task: 'Build a pre-aggregation that updates itself on every insert. Create <code>practice.raw_readings</code> with the same structure as <code>meters.readings</code>. Create <code>practice.daily_agg</code> (AggregatingMergeTree) holding, per meter and UTC day, the reading count, min(value) and max(value). Connect them with a materialized view. Then insert meters 1–20 in two batches: January first, then February–March. Run the check query and paste its result.',
   verify_note: true,
   cols: 'day, readings, spread', order: 'day',
   hint: 'Use columns of type AggregateFunction(count), AggregateFunction(min, Decimal(12, 3)) and AggregateFunction(max, Decimal(12, 3)). The MV uses countState(), minState(value), maxState(value), and you read them with countMerge, minMerge, maxMerge. Create the MV before you insert. For simple functions like min, max and sum, SimpleAggregateFunction(min, …) is a lighter alternative you will often see in real projects; try it after you get this version working.',
   setup: <<~'SQL',
     CREATE TABLE practice.raw_readings AS meters.readings;
     CREATE TABLE practice.daily_agg
     (
         meter_id  UInt32,
         day       Date,
         readings  AggregateFunction(count),
         min_value AggregateFunction(min, Decimal(12, 3)),
         max_value AggregateFunction(max, Decimal(12, 3))
     )
     ENGINE = AggregatingMergeTree
     ORDER BY (meter_id, day);
     CREATE MATERIALIZED VIEW practice.daily_agg_mv TO practice.daily_agg AS
     SELECT meter_id, toDate(ts) AS day, countState() AS readings, minState(value) AS min_value, maxState(value) AS max_value
     FROM practice.raw_readings
     GROUP BY meter_id, day;
     INSERT INTO practice.raw_readings SELECT * FROM meters.readings WHERE meter_id <= 20 AND ts < '2026-02-01';
     INSERT INTO practice.raw_readings SELECT * FROM meters.readings WHERE meter_id <= 20 AND ts >= '2026-02-01';
   SQL
   verify: <<~'SQL'
     SELECT day, countMerge(readings) AS readings, maxMerge(max_value) - minMerge(min_value) AS spread
     FROM practice.daily_agg
     WHERE meter_id = 1 AND day BETWEEN '2026-01-31' AND '2026-02-02'
     GROUP BY day
     ORDER BY day
   SQL

ex id: 32, mod: 7, title: 'Dictionary lookup', where: 'local', data: 'meters + customers → dictionary', skills: %w[CREATE\ USER GRANT DICTIONARY dictGet],
   task: 'Dictionaries are in-memory lookups and are often faster than JOINs. (1) Create a user <code>dict_reader</code> with password <code>dict_reader_pw</code> that can connect only from inside the server (<code>HOST LOCAL</code>), and give it SELECT on <code>meters.*</code>. (2) Create a dictionary <code>practice.meter_info</code> keyed by meter_id, with the attributes utility, segment and city, built from a query that joins meters and customers, using that user. Run the check query and paste its result.',
   verify_note: true,
   cols: 'segment, readings', order: 'segment',
   hint: "SOURCE(CLICKHOUSE(QUERY '…' USER 'dict_reader' PASSWORD 'dict_reader_pw')) LAYOUT(HASHED()) LIFETIME(MIN 0 MAX 3600). A HASHED dictionary stores its key as UInt64, so declare meter_id UInt64 and pass toUInt64(meter_id) to dictGet.",
   setup: <<~'SQL',
     DROP USER IF EXISTS dict_reader;
     CREATE USER dict_reader IDENTIFIED BY 'dict_reader_pw' HOST LOCAL;
     GRANT SELECT ON meters.* TO dict_reader;
     CREATE DICTIONARY practice.meter_info
     (
         meter_id UInt64,
         utility  String,
         segment  String,
         city     String
     )
     PRIMARY KEY meter_id
     SOURCE(CLICKHOUSE(QUERY 'SELECT m.meter_id, m.utility, c.segment, c.city FROM meters.meters AS m INNER JOIN meters.customers AS c ON c.customer_id = m.customer_id' USER 'dict_reader' PASSWORD 'dict_reader_pw'))
     LAYOUT(HASHED())
     LIFETIME(MIN 0 MAX 3600);
   SQL
   verify: <<~'SQL'
     SELECT dictGet('practice.meter_info', 'segment', toUInt64(meter_id)) AS segment, count() AS readings
     FROM meters.readings
     WHERE dictGet('practice.meter_info', 'utility', toUInt64(meter_id)) = 'electricity' AND ts < '2026-02-01'
     GROUP BY segment
     ORDER BY segment
   SQL

ex id: 33, mod: 7, title: 'Reading the primary index', where: 'local', data: 'meters.readings', skills: %w[EXPLAIN\ indexes ORDER\ BY\ key], check: 'review',
   task: 'Run <code>EXPLAIN indexes = 1</code> for these three queries: (A) <code>SELECT count() FROM meters.readings WHERE meter_id = 7</code>, (B) <code>… WHERE toHour(ts) = 3</code>, and (C) <code>… WHERE ts >= \'2026-03-01\' AND ts < \'2026-03-02\'</code>. Paste the three outputs into Your result, then write in your SQL notes, in two or three sentences, why the numbers of parts and granules differ. Claude reviews this one; there is no automatic answer.',
   cols: 'EXPLAIN output + your explanation', order: '-',
   hint: 'Look at the MinMax, Partition and PrimaryKey sections. Which conditions can use ORDER BY (meter_id, ts), and which can only use the partition key?',
   solution: <<~'SQL'
     EXPLAIN indexes = 1 SELECT count() FROM meters.readings WHERE meter_id = 7;
     EXPLAIN indexes = 1 SELECT count() FROM meters.readings WHERE toHour(ts) = 3;
     EXPLAIN indexes = 1 SELECT count() FROM meters.readings WHERE ts >= '2026-03-01' AND ts < '2026-03-02';
     -- A: meter_id is the first ORDER BY column, so the primary index skips almost all granules.
     -- B: toHour(ts) can't use the index (every partition and every granule has hour 3), so it scans everything.
     -- C: ts is the second ORDER BY column. The partition key (toYYYYMM) and MinMax index keep only the March
     --    partition, but inside it ts is sorted only within each meter: every granule holds March 1 rows of
     --    some meter, so all granules of the March partition are read. Only the first ORDER BY column skips well.
   SQL

ex id: 34, mod: 7, title: '3.4 billion taxi trips', where: 'browser', data: 'nyc_taxi.trips (full)', skills: %w[filtering\ big\ tables],
   task: 'Run this one in the browser playground, where the table has about 3.4 billion rows. For January 2015 yellow cabs, return trips and average <code>total_amount</code> per <code>passenger_count</code> from 1 to 6. Filter on <code>pickup_date</code> so ClickHouse can skip most of the data.',
   cols: 'passenger_count, trips, avg_total (rounded to 2 decimals)', order: 'passenger_count',
   hint: "cab_type = 'yellow' AND pickup_date >= '2015-01-01' AND pickup_date < '2015-02-01'",
   solution: <<~'SQL'
     SELECT passenger_count, count() AS trips, round(avg(total_amount), 2) AS avg_total
     FROM nyc_taxi.trips
     WHERE pickup_date >= '2015-01-01' AND pickup_date < '2015-02-01'
       AND cab_type = 'yellow' AND passenger_count BETWEEN 1 AND 6
     GROUP BY passenger_count
     ORDER BY passenger_count
   SQL

ex id: 35, mod: 7, title: 'Sensor time series', where: 'browser', data: 'environmental.sensors (20B rows)', skills: %w[time\ series window\ functions],
   task: 'Run this one in the browser playground. Sensor readings work much like meter readings. For <code>sensor_id = 182</code> from 2022-06-01 to 2022-06-07 (filter on <code>timestamp</code>; the <code>date</code> column is empty), return per day: readings, min, avg and max temperature, and the largest gap between two consecutive readings, where gap = <code>dateDiff(\'minute\', previous timestamp, timestamp)</code>. Count every reading in the stats; only the week\'s very first reading has no gap.',
   cols: 'day, readings, min_temp, avg_temp, max_temp (temps rounded to 1 decimal), max_gap_min', order: 'day',
   hint: 'Calculate the gap with lagInFrame(timestamp) over the whole week, then aggregate per day. Don\'t filter out the first row, or June 1 loses a reading: use max(if(rn > 1, gap_min, NULL)) so only the gap ignores it. dateDiff(\'minute\', …) counts minute boundaries crossed, which can be 1 more than seconds / 60.',
   solution: <<~'SQL'
     SELECT toDate(timestamp) AS day,
            count() AS readings,
            round(min(temperature), 1) AS min_temp,
            round(avg(temperature), 1) AS avg_temp,
            round(max(temperature), 1) AS max_temp,
            max(if(rn > 1, gap_min, NULL)) AS max_gap_min
     FROM
     (
         SELECT timestamp, temperature,
                dateDiff('minute', lagInFrame(timestamp) OVER w, timestamp) AS gap_min,
                row_number() OVER w AS rn
         FROM environmental.sensors
         WHERE sensor_id = 182 AND timestamp >= '2022-06-01 00:00:00' AND timestamp < '2022-06-08 00:00:00'
         WINDOW w AS (ORDER BY timestamp)
     )
     GROUP BY day
     ORDER BY day
   SQL

# ---------------------------------------------------------------- Module 8
CLEAN_RULES = 'Use the clean-consumption rules from the Meter data rules section: (1) deduplicate, keeping the newest ingested_at; (2) drop a glitch reading whose value is higher than the next reading, unless the next reading is a meter replacement; (3) interval consumption = value − previous value, except that the first reading at or after a replacement counts its own value; (4) skip each meter\'s very first reading. A replacement happens at <code>install_date</code> 00:00 <b>UTC</b>, i.e. <code>toDateTime(install_date, \'UTC\')</code>; readings with ts at or after that come from the new meter. Each interval\'s consumption belongs to the date and hour of its reading\'s <code>ts</code> (the end of the interval).'

ex id: 36, mod: 8, title: 'February bills', where: 'local', data: 'readings + meters + customers + tariffs', skills: %w[full\ pipeline tariffs time-of-use],
   task: "Calculate February 2026 bills for customers 17, 42, 50, 77 and 99. February means the reading's local month (Europe/Sarajevo). #{CLEAN_RULES} Electricity uses the day rate when the reading's local hour is between 7 and 22 (7 ≤ hour < 23) and the night rate otherwise; water uses its flat rate. Prices come from <code>meters.tariffs</code> by utility and segment.",
   cols: 'customer_id, electricity_kwh, water_m3, total_eur (all rounded to 2 decimals)', order: 'customer_id',
   hint: 'Work out rate_type (day / night / flat) on each consumption row, then do an equality JOIN to tariffs on (utility, segment, rate_type). Calculate the deltas over the whole quarter and filter to February at the end, so February 1 gets its delta from January 31.',
   solution: <<~'SQL'
     WITH
         dedup AS
         (
             SELECT meter_id, ts, argMax(value, ingested_at) AS value
             FROM meters.readings
             WHERE meter_id IN (SELECT meter_id FROM meters.meters WHERE customer_id IN (17, 42, 50, 77, 99))
             GROUP BY meter_id, ts
         ),
         flagged AS
         (
             SELECT d.meter_id, d.ts, d.value,
                    leadInFrame(d.value) OVER w AS next_value,
                    leadInFrame(d.ts) OVER w AS next_ts,
                    row_number() OVER w AS rn,
                    count() OVER w AS cnt
             FROM dedup AS d
             WINDOW w AS (PARTITION BY d.meter_id ORDER BY d.ts ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
         ),
         clean AS
         (
             SELECT f.meter_id, f.ts, f.value
             FROM flagged AS f
             INNER JOIN meters.meters AS m ON m.meter_id = f.meter_id
             WHERE NOT (f.rn < f.cnt AND f.value > f.next_value
                        AND NOT (f.ts < toDateTime(m.install_date, 'UTC') AND f.next_ts >= toDateTime(m.install_date, 'UTC')))
         ),
         deltas AS
         (
             SELECT meter_id, ts, value,
                    lagInFrame(value) OVER w AS prev_value,
                    lagInFrame(ts) OVER w AS prev_ts,
                    row_number() OVER w AS rn
             FROM clean
             WINDOW w AS (PARTITION BY meter_id ORDER BY ts)
         ),
         consumption AS
         (
             SELECT d.meter_id, d.ts, m.utility, m.customer_id,
                    if(d.prev_ts < toDateTime(m.install_date, 'UTC') AND d.ts >= toDateTime(m.install_date, 'UTC'),
                       d.value, d.value - d.prev_value) AS amount,
                    toHour(toTimeZone(d.ts, 'Europe/Sarajevo')) AS local_hour,
                    multiIf(m.utility = 'water', 'flat', local_hour >= 7 AND local_hour < 23, 'day', 'night') AS rate_type
             FROM deltas AS d
             INNER JOIN meters.meters AS m ON m.meter_id = d.meter_id
             WHERE d.rn > 1
               AND toStartOfMonth(toTimeZone(d.ts, 'Europe/Sarajevo')) = '2026-02-01'
         )
     SELECT x.customer_id AS customer_id,
            round(sumIf(x.amount, x.utility = 'electricity'), 2) AS electricity_kwh,
            round(sumIf(x.amount, x.utility = 'water'), 2) AS water_m3,
            round(sum(x.amount * t.price_eur), 2) AS total_eur
     FROM consumption AS x
     INNER JOIN meters.customers AS c ON c.customer_id = x.customer_id
     INNER JOIN meters.tariffs AS t ON t.utility = x.utility AND t.segment = c.segment AND t.rate_type = x.rate_type
     GROUP BY x.customer_id
     ORDER BY x.customer_id
   SQL

ex id: 37, mod: 8, title: 'March completeness report', where: 'local', data: 'readings + meters', skills: %w[KPIs reporting],
   task: 'Data quality KPI for March 2026 (UTC). Per utility, return: meters, expected readings (31 × 96 per electricity meter, 31 × 24 per water meter), received distinct readings, completeness % and the number of meters below 99% complete.',
   cols: 'utility, meters, expected_readings, received_readings, completeness_pct (rounded to 2 decimals), meters_below_99', order: 'utility',
   hint: 'Count distinct (meter_id, ts) per meter first, work out each meter\'s expected count, then aggregate per utility.',
   solution: <<~'SQL'
     SELECT m.utility,
            count() AS meters,
            sum(p.expected) AS expected_readings,
            sum(p.received) AS received_readings,
            round(received_readings / expected_readings * 100, 2) AS completeness_pct,
            countIf(p.received / p.expected < 0.99) AS meters_below_99
     FROM
     (
         SELECT r.meter_id, uniqExact(r.ts) AS received, if(any(m2.utility) = 'electricity', 31 * 96, 31 * 24) AS expected
         FROM meters.readings AS r
         INNER JOIN meters.meters AS m2 ON m2.meter_id = r.meter_id
         WHERE r.ts >= '2026-03-01' AND r.ts < '2026-04-01'
         GROUP BY r.meter_id
     ) AS p
     INNER JOIN meters.meters AS m ON m.meter_id = p.meter_id
     GROUP BY m.utility
     ORDER BY m.utility
   SQL

ex id: 38, mod: 8, title: 'Water leak detection', where: 'local', data: 'readings + meters + customers', skills: %w[gaps-and-islands streaks],
   task: 'A household or office should use no water in the middle of the night. For residential and commercial water meters (deduplicated, skipping the first reading), a night has continuous flow when every reading with local hour 2, 3 or 4 has consumption > 0. Find runs of at least 7 consecutive nights like that.',
   cols: 'meter_id, leak_start, nights', order: 'meter_id',
   hint: 'This is the "gaps and islands" pattern. Number each meter\'s flagged nights with row_number(); night minus that number is the same for every night in an unbroken run, so you can group by it. subtractDays(night, rn) works on Date.',
   solution: <<~'SQL'
     WITH
         dedup AS
         (
             SELECT meter_id, ts, argMax(value, ingested_at) AS value
             FROM meters.readings
             WHERE meter_id > 200
             GROUP BY meter_id, ts
         ),
         d AS
         (
             SELECT meter_id, ts,
                    value - lagInFrame(value) OVER w AS m3,
                    row_number() OVER w AS rn
             FROM dedup
             WINDOW w AS (PARTITION BY meter_id ORDER BY ts)
         ),
         nights AS
         (
             SELECT d.meter_id AS meter_id, toDate(d.ts, 'Europe/Sarajevo') AS night
             FROM d
             INNER JOIN meters.meters AS m ON m.meter_id = d.meter_id
             INNER JOIN meters.customers AS c ON c.customer_id = m.customer_id
             WHERE d.rn > 1
               AND c.segment IN ('residential', 'commercial')
               AND toHour(toTimeZone(d.ts, 'Europe/Sarajevo')) BETWEEN 2 AND 4
             GROUP BY d.meter_id, night
             HAVING min(d.m3) > 0
         ),
         islands AS
         (
             SELECT meter_id, night,
                    subtractDays(night, row_number() OVER (PARTITION BY meter_id ORDER BY night)) AS grp
             FROM nights
         )
     SELECT meter_id, min(night) AS leak_start, count() AS nights
     FROM islands
     GROUP BY meter_id, grp
     HAVING nights >= 7
     ORDER BY meter_id
   SQL

ex id: 39, mod: 8, title: 'Daily consumption table', where: 'local', data: 'meters.* → practice.daily_consumption', skills: %w[INSERT\ SELECT pipelines],
   task: "Build the table your reports would read from. Create <code>practice.daily_consumption (meter_id UInt32, local_date Date, consumption Decimal(18, 3))</code> ordered by <code>(meter_id, local_date)</code> and fill it for all meters and the whole quarter. #{CLEAN_RULES} Each interval's consumption counts toward the local date (Europe/Sarajevo) of its reading's <code>ts</code>. Run the check query and paste its result.",
   verify_note: true,
   cols: 'utility, rows, total (rounded to 2 decimals)', order: 'utility',
   hint: 'Reuse your exercise 36 CTEs without the customer filter and pricing, then GROUP BY meter_id, local_date in the INSERT … SELECT.',
   setup: <<~'SQL',
     CREATE TABLE practice.daily_consumption
     (
         meter_id    UInt32,
         local_date  Date,
         consumption Decimal(18, 3)
     )
     ENGINE = MergeTree
     ORDER BY (meter_id, local_date);
     INSERT INTO practice.daily_consumption
     WITH
         dedup AS
         (
             SELECT meter_id, ts, argMax(value, ingested_at) AS value
             FROM meters.readings
             GROUP BY meter_id, ts
         ),
         flagged AS
         (
             SELECT d.meter_id, d.ts, d.value,
                    leadInFrame(d.value) OVER w AS next_value,
                    leadInFrame(d.ts) OVER w AS next_ts,
                    row_number() OVER w AS rn,
                    count() OVER w AS cnt
             FROM dedup AS d
             WINDOW w AS (PARTITION BY d.meter_id ORDER BY d.ts ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
         ),
         clean AS
         (
             SELECT f.meter_id, f.ts, f.value
             FROM flagged AS f
             INNER JOIN meters.meters AS m ON m.meter_id = f.meter_id
             WHERE NOT (f.rn < f.cnt AND f.value > f.next_value
                        AND NOT (f.ts < toDateTime(m.install_date, 'UTC') AND f.next_ts >= toDateTime(m.install_date, 'UTC')))
         ),
         deltas AS
         (
             SELECT meter_id, ts, value,
                    lagInFrame(value) OVER w AS prev_value,
                    lagInFrame(ts) OVER w AS prev_ts,
                    row_number() OVER w AS rn
             FROM clean
             WINDOW w AS (PARTITION BY meter_id ORDER BY ts)
         )
     SELECT d.meter_id,
            toDate(d.ts, 'Europe/Sarajevo') AS local_date,
            sum(if(d.prev_ts < toDateTime(m.install_date, 'UTC') AND d.ts >= toDateTime(m.install_date, 'UTC'),
                   d.value, d.value - d.prev_value)) AS consumption
     FROM deltas AS d
     INNER JOIN meters.meters AS m ON m.meter_id = d.meter_id
     WHERE d.rn > 1
     GROUP BY d.meter_id, local_date;
   SQL
   verify: <<~'SQL'
     SELECT m.utility, count() AS rows, round(sum(d.consumption), 2) AS total
     FROM practice.daily_consumption AS d
     INNER JOIN meters.meters AS m ON m.meter_id = d.meter_id
     GROUP BY m.utility
     ORDER BY m.utility
   SQL

ex id: 40, mod: 8, title: 'Design the production schema', where: 'local', data: 'your design', skills: %w[architecture review], check: 'review',
   task: 'Design the ClickHouse schema you would propose for the real project: about 500,000 electricity and water meters, 15-minute readings, a feed that sends duplicates, corrections and late data, and reports by customer, local day and month. Write the DDL in your SQL notes: a raw table, the deduplication strategy, a materialized view or pre-aggregation for hourly or daily data, TTL or retention, and ORDER BY / PARTITION BY choices. Add short comments explaining why. Claude reviews it like a senior engineer would.',
   cols: 'DDL + comments', order: '-',
   hint: 'Think about which queries run most often (one meter over time? all meters for one day?), how many rows a year that is (500k × 96 × 365 ≈ 17.5B), and what happens when a correction arrives for a day that is already aggregated.',
   solution: <<~'SQL'
     -- One reasonable design (there are others):
     -- 1. Raw landing table, append-only, keeps every version. Cheap to re-process.
     CREATE TABLE energy.readings_raw
     (
         meter_id    UInt32,
         ts          DateTime('UTC') CODEC(DoubleDelta, ZSTD),
         value       Decimal(14, 3)  CODEC(Delta, ZSTD),        -- cumulative counter: small deltas compress very well
         ingested_at DateTime('UTC') CODEC(DoubleDelta, ZSTD),
         source      LowCardinality(String)
     )
     ENGINE = MergeTree                              -- plain MergeTree: keeps every delivered version (audit, replay)
     PARTITION BY toYYYYMM(ts)                       -- monthly partitions: ~1.5B rows each, easy DROP/reload
     ORDER BY (meter_id, ts, ingested_at)            -- most queries: one meter / many meters over a time range
     TTL ingested_at + INTERVAL 1 YEAR DELETE;       -- raw retention; the clean layer is kept longer
     -- 1b. Clean layer: one row per (meter_id, ts), newest version wins. Filled from raw by an MV or the dbt job.
     CREATE TABLE energy.readings
     (
         meter_id    UInt32,
         ts          DateTime('UTC') CODEC(DoubleDelta, ZSTD),
         value       Decimal(14, 3)  CODEC(Delta, ZSTD),
         ingested_at DateTime('UTC') CODEC(DoubleDelta, ZSTD)
     )
     ENGINE = ReplacingMergeTree(ingested_at)        -- dedup on merge; read with FINAL (or argMax) for exact results
     PARTITION BY toYYYYMM(ts)
     ORDER BY (meter_id, ts);
     -- 2. Hourly aggregate fed by MV. Cumulative registers need deltas, which need the previous reading,
     --    so a common approach is to store min/max per hour (Aggregating) and compute consumption as
     --    differences between consecutive hours at query time, OR run a scheduled (e.g. hourly) INSERT…SELECT
     --    job that recomputes recent days from readings_raw FINAL, so late data and corrections are absorbed.
     -- 3. daily_consumption (ReplacingMergeTree(version) ORDER BY (meter_id, local_date)) rebuilt per day by the job;
     --    reports by customer join via a dictionary (meter -> customer, segment, tariff), not a big JOIN.
   SQL

# ---------------------------------------------------------------- Module 9 (browser, big tables)
SENSOR_NOTE = ' The table is sorted by <code>(timestamp, sensor_id)</code>, so always filter on <code>timestamp</code> first; the <code>date</code> column is empty.'

ex id: 41, mod: 9, title: 'Sensor fleet in one day', where: 'browser', data: 'environmental.sensors (20B rows)', skills: %w[sort-key\ filter uniqExact],
   task: "Get a first picture of a big fleet. For 2022-06-01 (UTC), return the 5 sensor types with the most readings, with the number of distinct sensors of each type.#{SENSOR_NOTE}",
   cols: 'sensor_type, sensors, readings', order: 'readings descending',
   hint: "timestamp >= '2022-06-01 00:00:00' AND timestamp < '2022-06-02 00:00:00'. Use a half-open range like this for every time filter, so midnight is never counted twice.",
   solution: <<~'SQL'
     SELECT sensor_type, uniqExact(sensor_id) AS sensors, count() AS readings
     FROM environmental.sensors
     WHERE timestamp >= '2022-06-01 00:00:00' AND timestamp < '2022-06-02 00:00:00'
     GROUP BY sensor_type
     ORDER BY readings DESC
     LIMIT 5
   SQL

ex id: 42, mod: 9, title: 'Gaps across 5,000 sensors', where: 'browser', data: 'environmental.sensors', skills: %w[groupArray arrayDifference arrays\ vs\ windows],
   task: "Find the largest gap between two consecutive readings of each BME280 sensor on 2022-06-01, counting only sensors with at least 100 readings that day. Return how many sensors qualify and how many of them had a gap longer than 30 minutes. This is the same completeness check you would run on every meter every night.#{SENSOR_NOTE}",
   cols: 'sensors, sensors_with_gap_over_30min', order: '-',
   hint: 'Window functions work, but arrays are often faster in ClickHouse: arraySort(groupArray(toUInt32(timestamp))), then arrayDifference, then arrayMax, all per sensor_id. A gap longer than 30 minutes means more than 1,800 seconds.',
   solution: <<~'SQL'
     SELECT count() AS sensors, countIf(max_gap_s > 1800) AS sensors_with_gap_over_30min
     FROM
     (
         SELECT sensor_id,
                arrayMax(arrayDifference(arraySort(groupArray(toUInt32(timestamp))))) AS max_gap_s
         FROM environmental.sensors
         WHERE sensor_type = 'BME280'
           AND timestamp >= '2022-06-01 00:00:00' AND timestamp < '2022-06-02 00:00:00'
         GROUP BY sensor_id
         HAVING count() >= 100
     )
   SQL

ex id: 43, mod: 9, title: 'Stuck sensors', where: 'browser', data: 'environmental.sensors', skills: %w[HAVING min=max error\ codes],
   task: "A healthy sensor's temperature changes over a day. A sensor reporting the same value all day is stuck, just like a meter register that never moves. For BME280 sensors on 2022-06-01 with at least 100 readings, find the ones whose temperature never changed. Return how many are stuck, and how many of those are stuck below −40 °C, which is a hardware error value rather than a real temperature.#{SENSOR_NOTE}",
   cols: 'stuck_sensors, stuck_at_error_value', order: '-',
   hint: 'Per sensor: HAVING count() >= 100 AND min(temperature) = max(temperature). Keep any(temperature) AS stuck_value, then count in an outer query.',
   solution: <<~'SQL'
     SELECT count() AS stuck_sensors, countIf(stuck_value < -40) AS stuck_at_error_value
     FROM
     (
         SELECT sensor_id, any(temperature) AS stuck_value
         FROM environmental.sensors
         WHERE sensor_type = 'BME280'
           AND timestamp >= '2022-06-01 00:00:00' AND timestamp < '2022-06-02 00:00:00'
         GROUP BY sensor_id
         HAVING count() >= 100 AND min(temperature) = max(temperature)
     )
   SQL

ex id: 44, mod: 9, title: 'Hourly fleet heartbeat', where: 'browser', data: 'environmental.sensors', skills: %w[toStartOfHour completeness],
   task: "For DHT22 sensors on 2022-06-01, return per hour the number of readings and the number of distinct sensors that reported. A dip in a chart of this result is how you would spot a feed outage.#{SENSOR_NOTE}",
   cols: 'hour, readings, sensors', order: 'hour',
   hint: 'toStartOfHour(timestamp) AS hour. You should get 24 rows.',
   solution: <<~'SQL'
     SELECT toStartOfHour(timestamp) AS hour, count() AS readings, uniqExact(sensor_id) AS sensors
     FROM environmental.sensors
     WHERE sensor_type = 'DHT22'
       AND timestamp >= '2022-06-01 00:00:00' AND timestamp < '2022-06-02 00:00:00'
     GROUP BY hour
     ORDER BY hour
   SQL

ex id: 45, mod: 9, title: 'The silent wrong answer', where: 'browser', data: 'environmental.sensors', skills: %w[ORDER\ BY\ key read\ limits],
   task: "(1) Count the readings of <code>sensor_id = 182</code> in June 2022 and return them with the first and last timestamp. That is the result to paste. (2) Then run <code>SELECT count() FROM environmental.sensors WHERE sensor_id = 182</code> with no time filter, two or three times. Compare the numbers and the rows read shown under the result. In Your SQL, write in two sentences what happened and why. The playground stops reading after 1 billion rows and returns what it has, without an error.",
   cols: 'readings, first_ts, last_ts', order: '-',
   hint: 'The table is sorted by (timestamp, sensor_id). A filter on sensor_id alone can\'t skip any data, because sensor 182 appears in every time range. Your server has a similar setting: read_overflow_mode = \'break\' returns partial results.',
   solution: <<~'SQL'
     SELECT count() AS readings, min(timestamp) AS first_ts, max(timestamp) AS last_ts
     FROM environmental.sensors
     WHERE sensor_id = 182
       AND timestamp >= '2022-06-01 00:00:00' AND timestamp < '2022-07-01 00:00:00';

     -- Without a time filter the count changes between runs (e.g. 280,089 then 91,743):
     -- sensor_id is the SECOND column of ORDER BY (timestamp, sensor_id), so the index cannot skip anything,
     -- ClickHouse reads ~1B of the 20.7B rows, hits max_rows_to_read with read_overflow_mode = 'break',
     -- and returns a partial count with no error. Always put the leading sort-key column in the WHERE.
   SQL

ex id: 46, mod: 9, title: 'Physically impossible values', where: 'browser', data: 'environmental.sensors', skills: %w[countIf validation],
   task: "Validate before you aggregate. For the temperature sensor types (BME280, BMP180, BMP280, DHT22, DS18B20, HTU21D) on 2022-06-01, count all readings, the invalid ones (temperature below −40 or above 60), and the invalid share in %. In the meter project you'll run the same check for negative or impossible consumption.#{SENSOR_NOTE}",
   cols: 'sensor_type, readings, invalid, invalid_pct (rounded to 2 decimals)', order: 'sensor_type (alphabetical)',
   hint: "sensor_type is an Enum, so you can compare it with strings: sensor_type IN ('BME280', …).",
   solution: <<~'SQL'
     SELECT sensor_type,
            count() AS readings,
            countIf(temperature < -40 OR temperature > 60) AS invalid,
            round(invalid / readings * 100, 2) AS invalid_pct
     FROM environmental.sensors
     WHERE timestamp >= '2022-06-01 00:00:00' AND timestamp < '2022-06-02 00:00:00'
       AND sensor_type IN ('BME280', 'BMP180', 'BMP280', 'DHT22', 'DS18B20', 'HTU21D')
     GROUP BY sensor_type
     ORDER BY toString(sensor_type)
   SQL

ex id: 47, mod: 9, title: 'Filter on the sort key', where: 'browser', data: 'github.github_events (10B+ rows)', skills: %w[primary\ index rows\ read],
   task: 'The GitHub events table is sorted by <code>(repo_id, event_type, created_at)</code>. For the ClickHouse repository (<code>repo_id = \'60246359\'</code>, a string), return the 5 most common event types in 2023 and the number of distinct people (<code>actor_login</code>) behind each. Then run the same query filtering on <code>repo_name = \'ClickHouse/ClickHouse\'</code> instead, and write in Your SQL how many rows each version read.',
   cols: 'event_type, events, people', order: 'events descending',
   hint: 'The web UI shows rows read under the result. Expect hundreds of thousands of rows for one filter and hundreds of millions for the other.',
   solution: <<~'SQL'
     SELECT event_type, count() AS events, uniqExact(actor_login) AS people
     FROM github.github_events
     WHERE repo_id = '60246359'
       AND created_at >= '2023-01-01 00:00:00' AND created_at < '2024-01-01 00:00:00'
     GROUP BY event_type
     ORDER BY events DESC
     LIMIT 5;
     -- repo_id filter: a few hundred thousand rows read. repo_name filter: ~250M rows read for the same answer,
     -- because repo_name is not in the ORDER BY key. Meter tables: put meter_id first for the same reason.
   SQL

ex id: 48, mod: 9, title: 'Enums on the full UK table', where: 'browser', data: 'uk.uk_price_paid (31M rows)', skills: %w[Enum LowCardinality],
   task: 'In the playground\'s copy of the UK table, <code>type</code> is an Enum with readable labels (detached, flat …); in your local copy it is a plain number. For sales dated in 2022, return per property type the number of sales and the average price. Afterwards, compare with your local table and work out which number stands for which label.',
   cols: 'type, sales, avg_price (rounded to whole pounds)', order: 'avg_price descending',
   hint: "date >= '2022-01-01' AND date < '2023-01-01'. Run SELECT DISTINCT type FROM uk.uk_price_paid to see the Enum labels.",
   solution: <<~'SQL'
     SELECT type, count() AS sales, round(avg(price)) AS avg_price
     FROM uk.uk_price_paid
     WHERE date >= '2022-01-01' AND date < '2023-01-01'
     GROUP BY type
     ORDER BY avg_price DESC
   SQL

# ---------------------------------------------------------------- Module 10 (S3 bucket + dbt, local)
LAKE_NOTE = ' The bucket is reached through the named collection <code>lake</code>, which holds the URL and the keys so they never appear in your SQL: <code>s3(lake, filename = \'readings/…\')</code>.'
DBT_RUN = 'Run dbt from the repo folder with <code>docker compose run --rm dbt …</code>; your models live in <code>dbt/meter_project/</code>.'
DBT_FILES = {}

STG_TABLE = <<~'SQL'
  {{ config(
      materialized = 'table',
      engine       = 'MergeTree',
      order_by     = '(meter_id, ts)',
      partition_by = 'toYYYYMM(ts)'
  ) }}

  -- one row per (meter_id, ts): the newest delivery wins
  -- note r.ingested_at: without the table alias, ClickHouse would resolve `ingested_at`
  -- to the max(...) alias below and fail with "aggregate inside another aggregate"
  select
      r.meter_id                     as meter_id,
      r.ts                           as ts,
      argMax(r.value, r.ingested_at) as value,
      max(r.ingested_at)             as ingested_at
  from {{ source('lake', 'readings_raw') }} as r
  group by r.meter_id, r.ts
SQL

DAILY = <<~'SQL'
  {{ config(
      materialized = 'table',
      engine       = 'MergeTree',
      order_by     = '(meter_id, local_date)'
  ) }}

  with
      meters as (
          select meter_id, toDateTime(install_date, 'UTC') as installed_at
          from {{ ref('stg_meters') }}
      ),
      flagged as (
          select
              r.meter_id, r.ts, r.value,
              leadInFrame(r.value) over w as next_value,
              leadInFrame(r.ts)    over w as next_ts,
              row_number()         over w as rn,
              count()              over w as cnt
          from {{ ref('stg_readings') }} as r
          window w as (partition by r.meter_id order by r.ts rows between unbounded preceding and unbounded following)
      ),
      clean as (   -- drop glitches: higher than the next reading, unless the next one is a replacement
          select f.meter_id, f.ts, f.value
          from flagged as f
          inner join meters as m on m.meter_id = f.meter_id
          where not (f.rn < f.cnt and f.value > f.next_value
                     and not (f.ts < m.installed_at and f.next_ts >= m.installed_at))
      ),
      deltas as (
          select
              meter_id, ts, value,
              lagInFrame(value) over w as prev_value,
              lagInFrame(ts)    over w as prev_ts,
              row_number()      over w as rn
          from clean
          window w as (partition by meter_id order by ts)
      )
  select
      d.meter_id                           as meter_id,
      toDate(d.ts, 'Europe/Sarajevo')      as local_date,
      sum(if(d.prev_ts < m.installed_at and d.ts >= m.installed_at,
             d.value,                      -- first reading of a new meter counts from 0
             d.value - d.prev_value))      as consumption
  from deltas as d
  inner join meters as m on m.meter_id = d.meter_id
  where d.rn > 1
  group by d.meter_id, local_date
SQL

SCHEMA_YML = <<~'YML'
  version: 2
  models:
    - name: daily_consumption
      description: Clean consumption per meter and local day (Europe/Sarajevo).
      columns:
        - name: meter_id
          data_tests:
            - not_null
            - relationships:
                arguments:
                  to: ref('stg_meters')
                  field: meter_id
        - name: local_date
          data_tests: [not_null]
        - name: consumption
          data_tests: [not_null]
YML

TEST_NEG = <<~'SQL'
  -- A singular test: dbt fails the test if this query returns any rows.
  select meter_id, local_date, consumption
  from {{ ref('daily_consumption') }}
  where consumption < 0
SQL

TEST_UNIQ = <<~'SQL'
  select meter_id, local_date, count() as n
  from {{ ref('daily_consumption') }}
  group by meter_id, local_date
  having n > 1
SQL

STG_INCR = <<~'SQL'
  {{ config(
      materialized         = 'incremental',
      incremental_strategy = 'append',
      engine               = 'ReplacingMergeTree(ingested_at)',
      order_by             = '(meter_id, ts)',
      partition_by         = 'toYYYYMM(ts)'
  ) }}

  -- Incremental: each run only reads rows that reached lake.readings_raw since the last run.
  -- We filter on loaded_at (when WE received the row), not on ts (when it was measured),
  -- so late readings and corrections are always picked up. The 1-hour overlap is safe because
  -- ReplacingMergeTree(ingested_at) keeps only the newest version of each (meter_id, ts).
  select meter_id, ts, value, ingested_at, loaded_at
  from {{ source('lake', 'readings_raw') }}
  {% if is_incremental() %}
  where loaded_at > (select max(loaded_at) - interval 1 hour from {{ this }})
  {% endif %}
SQL

DAILY_FINAL = DAILY.sub("from {{ ref('stg_readings') }} as r\n", "from {{ ref('stg_readings') }} as r final   -- FINAL: read the deduplicated version\n")
raise 'DAILY_FINAL not patched' if DAILY_FINAL == DAILY

def dbt_solution(files, cmds, verify = nil)
  parts = files.map { |path, body| "-- ===== file: dbt/meter_project/#{path} =====\n#{body.rstrip}" }
  parts << "-- ===== then run =====\n" + cmds.map { |c| "-- docker compose run --rm dbt #{c}" }.join("\n")
  parts << "-- ===== check query =====\n#{verify.strip}" if verify
  parts.join("\n\n")
end

ex id: 49, mod: 10, title: "What's in the bucket", where: 'local', data: 's3://meter-raw/readings/', skills: %w[s3() _path globs],
   task: "The meter head-end system delivers one Parquet file per day into the bucket, under <code>readings/YYYY/MM/DD.parquet</code>. Without loading anything, query the files in place and return the number of files, the total rows, and the first and last file path.#{LAKE_NOTE}",
   cols: 'files, rows, first_file, last_file (the full _path, including the bucket name)', order: '-',
   hint: "filename = 'readings/**.parquet' matches every folder level. The virtual column _path holds the file each row came from. Group by it in a subquery, then summarise.",
   solution: <<~'SQL'
     SELECT count() AS files, sum(rows) AS rows, min(file) AS first_file, max(file) AS last_file
     FROM
     (
         SELECT _path AS file, count() AS rows
         FROM s3(lake, filename = 'readings/**.parquet')
         GROUP BY file
     )
   SQL

ex id: 50, mod: 10, title: 'Delivery day is not reading day', where: 'local', data: 's3://meter-raw/readings/2026/03/', skills: %w[globs late\ data],
   task: "Files are named after the day they were <em>delivered</em>, not the day the readings were measured. Query only the March 2026 files and return how many files there are, how many rows they hold, and how many of those rows were measured before 2026-03-01 00:00 UTC. Look at the file list: one of them shouldn't be there.#{LAKE_NOTE}",
   cols: 'files, rows, readings_before_march', order: '-',
   hint: "filename = 'readings/2026/03/*.parquet'. uniqExact(_path) counts the files.",
   solution: <<~'SQL'
     SELECT uniqExact(_path) AS files, count() AS rows, countIf(ts < '2026-03-01') AS readings_before_march
     FROM s3(lake, filename = 'readings/2026/03/*.parquet')
   SQL

ex id: 51, mod: 10, title: 'Load January into a raw table', where: 'local', data: 'S3 → lake.readings_raw', skills: %w[INSERT\ SELECT\ FROM\ s3 lineage],
   task: "Create database <code>lake</code> and table <code>lake.readings_raw</code> with the four reading columns plus <code>source_file LowCardinality(String)</code> (which file the row came from) and <code>loaded_at DateTime('UTC') DEFAULT now()</code>. Use a MergeTree partitioned by month and ordered by <code>(meter_id, ts)</code>. Load only the files delivered in January 2026. Keep every row as delivered, without deduplicating: raw tables are a faithful copy of the source. Run the check query and paste its result.",
   verify_note: true,
   cols: 'rows, files, first_ts, last_ts', order: '-',
   hint: 'Parquet columns come back Nullable. ClickHouse converts them to your non-Nullable columns on INSERT as long as no value is NULL. Fill source_file from _path.',
   setup: <<~'SQL',
     DROP DATABASE IF EXISTS lake;
     CREATE DATABASE lake;
     CREATE TABLE lake.readings_raw
     (
         meter_id    UInt32,
         ts          DateTime('UTC'),
         value       Decimal(12, 3),
         ingested_at DateTime('UTC'),
         source_file LowCardinality(String),
         loaded_at   DateTime('UTC') DEFAULT now()
     )
     ENGINE = MergeTree
     PARTITION BY toYYYYMM(ts)
     ORDER BY (meter_id, ts);
     INSERT INTO lake.readings_raw (meter_id, ts, value, ingested_at, source_file)
     SELECT meter_id, ts, value, ingested_at, _path
     FROM s3(lake, filename = 'readings/2026/01/*.parquet');
   SQL
   verify: <<~'SQL'
     SELECT count() AS rows, uniqExact(source_file) AS files, min(ts) AS first_ts, max(ts) AS last_ts
     FROM lake.readings_raw
   SQL

ex id: 52, mod: 10, title: 'Load only new files', where: 'local', data: 'S3 → lake.readings_raw', skills: %w[idempotent\ loads incremental\ ingestion],
   task: 'A nightly Airflow job runs the same load every day, so it must pick up only files it hasn\'t loaded yet, and running it twice must change nothing. Write one INSERT that loads every file not yet in <code>lake.readings_raw</code>. Run it, then run it again. Run the check query and paste its result.',
   verify_note: true,
   cols: 'rows, files', order: '-',
   hint: "WHERE _path NOT IN (SELECT DISTINCT source_file FROM lake.readings_raw). A filter on _path also lets ClickHouse skip reading those files at all. In production the S3Queue engine does this bookkeeping for you.",
   setup: <<~'SQL',
     INSERT INTO lake.readings_raw (meter_id, ts, value, ingested_at, source_file)
     SELECT meter_id, ts, value, ingested_at, _path
     FROM s3(lake, filename = 'readings/**.parquet')
     WHERE _path NOT IN (SELECT DISTINCT source_file FROM lake.readings_raw);
     INSERT INTO lake.readings_raw (meter_id, ts, value, ingested_at, source_file)
     SELECT meter_id, ts, value, ingested_at, _path
     FROM s3(lake, filename = 'readings/**.parquet')
     WHERE _path NOT IN (SELECT DISTINCT source_file FROM lake.readings_raw);
   SQL
   verify: <<~'SQL'
     SELECT count() AS rows, uniqExact(source_file) AS files
     FROM lake.readings_raw
   SQL

ex id: 53, mod: 10, title: 'Spot the resent file', where: 'local', data: 'lake.readings_raw', skills: %w[content\ hashing self-join],
   task: 'Sometimes a supplier sends the same file twice under a different name. Using only <code>lake.readings_raw</code>, find files whose content is identical to another file: same row count and the same order-independent fingerprint of their rows. Return each duplicate with the file it copies, where <code>file</code> is the name that sorts later.',
   cols: 'file, duplicate_of', order: 'file',
   hint: 'Per source_file: count() and sum(cityHash64(meter_id, ts, value, ingested_at)). A sum of row hashes doesn\'t depend on row order. Join that result to itself on the fingerprint, with f.source_file > g.source_file.',
   solution: <<~'SQL'
     WITH fp AS
     (
         SELECT source_file, count() AS c, sum(cityHash64(meter_id, ts, value, ingested_at)) AS h
         FROM lake.readings_raw
         GROUP BY source_file
     )
     SELECT f.source_file AS file, g.source_file AS duplicate_of
     FROM fp AS f
     INNER JOIN fp AS g ON f.h = g.h AND f.c = g.c AND f.source_file > g.source_file
     ORDER BY file
   SQL

V54 = <<~'SQL'
  SELECT count() AS rows, sum(value) AS total_value
  FROM analytics.stg_readings
SQL
ex id: 54, mod: 10, title: 'Your first dbt model', where: 'local', data: 'lake.readings_raw → analytics.stg_readings', skills: %w[dbt\ model source() config()],
   task: "#{DBT_RUN} Create <code>models/staging/stg_readings.sql</code>: one row per <code>(meter_id, ts)</code> from <code>source('lake', 'readings_raw')</code>, keeping the value with the newest <code>ingested_at</code>. Override the folder default (view) so it is saved as a MergeTree table ordered by <code>(meter_id, ts)</code> and partitioned by month. Run <code>docker compose run --rm dbt run --select stg_readings</code>, then run the check query and paste its result. If your answer to exercise 15 was right, the numbers will look familiar.",
   verify_note: true,
   cols: 'rows, total_value', order: '-',
   hint: "{{ config(materialized='table', engine='MergeTree', order_by='(meter_id, ts)', partition_by='toYYYYMM(ts)') }}. Watch out: if you name the result max(ingested_at) AS ingested_at, the argMax next to it refers to that alias. Alias the source table and write r.ingested_at.",
   dbt_files: { 'models/staging/stg_readings.sql' => STG_TABLE },
   dbt_cmds: ['run --select stg_readings'],
   verify: V54,
   solution: dbt_solution({ 'models/staging/stg_readings.sql' => STG_TABLE }, ['run --select stg_readings'], V54)

V55 = <<~'SQL'
  SELECT m.utility, count() AS rows, round(sum(d.consumption), 2) AS total
  FROM analytics.daily_consumption AS d
  INNER JOIN analytics.stg_meters AS m ON m.meter_id = d.meter_id
  GROUP BY m.utility
  ORDER BY m.utility
SQL
ex id: 55, mod: 10, title: 'Chain models with ref()', where: 'local', data: 'stg_readings + stg_meters → daily_consumption', skills: %w[ref() lineage marts],
   task: "Turn your exercise 39 query into <code>models/marts/daily_consumption.sql</code>, reading from <code>{{ ref('stg_readings') }}</code> and <code>{{ ref('stg_meters') }}</code> instead of the <code>meters</code> tables, and saved as a table ordered by <code>(meter_id, local_date)</code>. Run <code>docker compose run --rm dbt build</code>: dbt works out the order from your <code>ref()</code> calls. Run the check query and paste its result. It should match exercise 39 exactly, because the data went through S3 and dbt but the logic is the same.",
   verify_note: true,
   cols: 'utility, rows, total (rounded to 2 decimals)', order: 'utility',
   hint: 'stg_meters already has install_date per meter. After the run, open dbt/meter_project/target/compiled/… to see the plain ClickHouse SQL dbt sent.',
   dbt_files: { 'models/marts/daily_consumption.sql' => DAILY },
   dbt_cmds: ['build'],
   verify: V55,
   solution: dbt_solution({ 'models/marts/daily_consumption.sql' => DAILY }, ['build'], V55)

ex id: 56, mod: 10, title: 'Data tests', where: 'local', data: 'dbt tests on daily_consumption', skills: %w[dbt\ test generic\ tests singular\ tests], check: 'review',
   task: "Add tests that run on every <code>dbt build</code>. (1) In <code>models/marts/schema.yml</code>: <code>not_null</code> on meter_id, local_date and consumption, plus a <code>relationships</code> test saying every meter_id exists in stg_meters. (2) Two singular tests in <code>tests/</code>: no negative consumption, and only one row per (meter_id, local_date). Run <code>docker compose run --rm dbt test</code>. Then break a test on purpose, for example by removing the replacement rule from step 3 of your model; rebuild and watch it fail. Paste both test outputs into Your result. Claude reviews this one.",
   cols: 'dbt test output', order: '-',
   hint: 'A singular test is a SELECT that returns the bad rows: zero rows means pass. In dbt 1.11, arguments for generic tests go under an arguments: key.',
   dbt_files: { 'models/marts/schema.yml' => SCHEMA_YML, 'tests/assert_no_negative_consumption.sql' => TEST_NEG, 'tests/assert_one_row_per_meter_day.sql' => TEST_UNIQ },
   dbt_cmds: ['test'],
   solution: dbt_solution({ 'models/marts/schema.yml' => SCHEMA_YML, 'tests/assert_no_negative_consumption.sql' => TEST_NEG, 'tests/assert_one_row_per_meter_day.sql' => TEST_UNIQ }, ['test'])

V57 = <<~'SQL'
  SELECT
      (SELECT count() FROM analytics.stg_readings FINAL) AS stg_rows,
      (SELECT round(sum(consumption), 2) FROM analytics.daily_consumption) AS daily_total
SQL
ex id: 57, mod: 10, title: 'Incremental model for late data', where: 'local', data: 'analytics.stg_readings (incremental)', skills: %w[incremental is_incremental() ReplacingMergeTree FINAL],
   task: "Rebuilding everything every night won't scale to billions of rows. Change <code>stg_readings</code> to an incremental model: ReplacingMergeTree(ingested_at), the <code>append</code> strategy, and on incremental runs only the rows whose <code>loaded_at</code> is newer than the latest one already in the model, minus a 1-hour safety overlap. Keep <code>loaded_at</code> as a column. Because the model now has duplicates until merges run, change daily_consumption to read <code>{{ ref('stg_readings') }} … FINAL</code>. Run <code>dbt run --select stg_readings --full-refresh</code> once, then <code>dbt build</code>. Run the check query and paste its result. Also compare <code>SELECT count() FROM analytics.stg_readings</code> with and without FINAL. In a real project the mart would be incremental too, rebuilding only the local dates that new rows touch (for example with the <code>delete+insert</code> or <code>insert_overwrite</code> strategy); ask your team which one they use.",
   verify_note: true,
   cols: 'stg_rows, daily_total', order: '-',
   hint: "{% if is_incremental() %} where loaded_at > (select max(loaded_at) - interval 1 hour from {{ this }}) {% endif %}. Filter on loaded_at, not ts: a reading measured last week can arrive today.",
   dbt_files: { 'models/staging/stg_readings.sql' => STG_INCR, 'models/marts/daily_consumption.sql' => DAILY_FINAL },
   dbt_cmds: ['run --select stg_readings --full-refresh', 'build'],
   verify: V57,
   solution: dbt_solution({ 'models/staging/stg_readings.sql' => STG_INCR, 'models/marts/daily_consumption.sql' => DAILY_FINAL }, ['run --select stg_readings --full-refresh', 'build'], V57)
