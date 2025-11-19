CREATE TABLE IF NOT EXISTS analytics.`sport_bespoke_bet_info`
(
    `id` Int64,
    `transaction_id` Int64,
    `coupon_id` Int64,
    `amount` Decimal(15,2),
    `currency` String,
    `bet_type` LowCardinality(String),
    `bet_data` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `player_id` Int32,
    `related_bet_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
