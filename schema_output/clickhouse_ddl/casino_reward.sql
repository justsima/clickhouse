CREATE TABLE IF NOT EXISTS analytics.`casino_reward`
(
    `id` Int64,
    `reward_type` LowCardinality(String),
    `reward_title` String,
    `txn_id` Int32,
    `amount` Decimal64(2),
    `currency` String,
    `created_at` DateTime64(6, 'UTC'),
    `player_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
