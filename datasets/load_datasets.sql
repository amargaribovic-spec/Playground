-- Loads small public ClickHouse example datasets into the local server.
-- Run:  docker compose exec -T clickhouse clickhouse-client --multiquery < datasets/load_datasets.sql
-- Safe to re-run: each table is dropped and recreated.

----------------------------------------------------------------------
-- IMDB (~50 MB compressed, ~5M rows across 7 tables)
----------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS imdb;

DROP TABLE IF EXISTS imdb.actors;
CREATE TABLE imdb.actors (id UInt32, first_name String, last_name String, gender FixedString(1))
ENGINE = MergeTree ORDER BY (id, first_name, last_name, gender);
INSERT INTO imdb.actors SELECT * FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/imdb/imdb_ijs_actors.tsv.gz', 'TSVWithNames');

DROP TABLE IF EXISTS imdb.directors;
CREATE TABLE imdb.directors (id UInt32, first_name String, last_name String)
ENGINE = MergeTree ORDER BY (id, first_name, last_name);
INSERT INTO imdb.directors SELECT * FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/imdb/imdb_ijs_directors.tsv.gz', 'TSVWithNames');

DROP TABLE IF EXISTS imdb.directors_genres;
CREATE TABLE imdb.directors_genres (director_id UInt32, genre String, prob Float32)
ENGINE = MergeTree ORDER BY (director_id, genre);
INSERT INTO imdb.directors_genres SELECT * FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/imdb/imdb_ijs_directors_genres.tsv.gz', 'TSVWithNames');

DROP TABLE IF EXISTS imdb.movies;
CREATE TABLE imdb.movies (id UInt32, name String, year UInt32, rank Float32 DEFAULT 0)
ENGINE = MergeTree ORDER BY (id, name, year);
INSERT INTO imdb.movies SELECT * FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/imdb/imdb_ijs_movies.tsv.gz', 'TSVWithNames');

DROP TABLE IF EXISTS imdb.movies_directors;
CREATE TABLE imdb.movies_directors (director_id UInt32, movie_id UInt32)
ENGINE = MergeTree ORDER BY (director_id, movie_id);
INSERT INTO imdb.movies_directors SELECT * FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/imdb/imdb_ijs_movies_directors.tsv.gz', 'TSVWithNames');

DROP TABLE IF EXISTS imdb.movies_genres;
CREATE TABLE imdb.movies_genres (movie_id UInt32, genre String)
ENGINE = MergeTree ORDER BY (movie_id, genre);
INSERT INTO imdb.movies_genres SELECT * FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/imdb/imdb_ijs_movies_genres.tsv.gz', 'TSVWithNames');

DROP TABLE IF EXISTS imdb.roles;
CREATE TABLE imdb.roles (actor_id UInt32, movie_id UInt32, role String)
ENGINE = MergeTree ORDER BY (actor_id, movie_id);
INSERT INTO imdb.roles SELECT * FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/imdb/imdb_ijs_roles.tsv.gz', 'TSVWithNames');

----------------------------------------------------------------------
-- UK property prices 1995-2023 (~250 MB Parquet, ~28M rows)
----------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS uk;

DROP TABLE IF EXISTS uk.uk_price_paid;
CREATE TABLE uk.uk_price_paid
(
    price     UInt32,
    date      Date,
    postcode1 LowCardinality(String),
    postcode2 LowCardinality(String),
    type      Int8,
    is_new    UInt8,
    duration  Int8,
    addr1     String,
    addr2     String,
    street    LowCardinality(String),
    locality  LowCardinality(String),
    town      LowCardinality(String),
    district  LowCardinality(String),
    county    LowCardinality(String)
)
ENGINE = MergeTree ORDER BY (postcode1, postcode2, addr1, addr2);
INSERT INTO uk.uk_price_paid
SELECT price, toDate('1970-01-01') + date, postcode1, postcode2, type, is_new, duration,
       addr1, addr2, street, locality, town, district, county
FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/uk-house-prices/parquet/house_prices.parquet', 'Parquet');

----------------------------------------------------------------------
-- NYC taxi, slice of ~3M trips (3 of the source files)
----------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS nyc_taxi;

DROP TABLE IF EXISTS nyc_taxi.trips;
CREATE TABLE nyc_taxi.trips
(
    trip_id           UInt32,
    pickup_datetime   DateTime,
    dropoff_datetime  DateTime,
    pickup_longitude  Nullable(Float64),
    pickup_latitude   Nullable(Float64),
    dropoff_longitude Nullable(Float64),
    dropoff_latitude  Nullable(Float64),
    passenger_count   UInt8,
    trip_distance     Float32,
    fare_amount       Float32,
    extra             Float32,
    tip_amount        Float32,
    tolls_amount      Float32,
    total_amount      Float32,
    payment_type      Enum('CSH' = 1, 'CRE' = 2, 'NOC' = 3, 'DIS' = 4, 'UNK' = 5),
    pickup_ntaname    LowCardinality(String),
    dropoff_ntaname   LowCardinality(String)
)
ENGINE = MergeTree PRIMARY KEY (pickup_datetime, dropoff_datetime);
INSERT INTO nyc_taxi.trips
SELECT trip_id, pickup_datetime, dropoff_datetime, pickup_longitude, pickup_latitude,
       dropoff_longitude, dropoff_latitude, passenger_count, trip_distance, fare_amount,
       extra, tip_amount, tolls_amount, total_amount, payment_type, pickup_ntaname, dropoff_ntaname
FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/nyc-taxi/trips_{0..2}.gz', 'TabSeparatedWithNames')
SETTINGS input_format_try_infer_datetimes = 0;
