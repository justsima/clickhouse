CREATE TABLE IF NOT EXISTS analytics.`cms_ug_playeractivity`
(
    `id` Int64,
    `player_id` Int32,
    `amount` Decimal64(2),
    `activity_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `action` String,
    `end_balance` Decimal64(2),
    `start_balance` Decimal64(2),
    `funds_type` LowCardinality(String),
    `currency_code` String,
    `description` String,
    `transaction_type` LowCardinality(String),
    `transaction_class` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
