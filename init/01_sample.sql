CREATE TABLE IF NOT EXISTS playground.events
(
    event_time DateTime,
    user_id    UInt32,
    event_type LowCardinality(String),
    amount     Decimal(10, 2)
)
ENGINE = MergeTree
ORDER BY (event_type, event_time);

INSERT INTO playground.events
SELECT
    now() - toIntervalSecond(number * 37),
    rand() % 1000,
    ['view', 'click', 'purchase'][rand() % 3 + 1],
    round(randUniform(1, 500), 2)
FROM numbers(100000);
