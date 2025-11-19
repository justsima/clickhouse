CREATE TABLE IF NOT EXISTS analytics.`raffle_prizedistribution`
(
    `id` Int64,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `prize_type` LowCardinality(String),
    `rank` UInt32,
    `amount` Nullable(Decimal(10,2)),
    `image` String DEFAULT '',
    `description` String DEFAULT '',
    `campaign_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
