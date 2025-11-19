CREATE TABLE IF NOT EXISTS analytics.`cms_ug_gamefundsinplaymovement`
(
    `id` Int64,
    `amount` Decimal64(2),
    `funds_type` LowCardinality(String),
    `currency_code` String,
    `transaction_type` LowCardinality(String),
    `transaction_class` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `game_fund_in_play_id` Int64,
    `activity_date` Date,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
