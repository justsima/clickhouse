CREATE TABLE IF NOT EXISTS analytics.`freebet_transaction`
(
    `id` Int64,
    `awarded_amount` Decimal64(2),
    `bonus_balance` Decimal64(2),
    `expired_amount` Decimal64(2),
    `expire_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `status` UInt16,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `owner_id` Int32,
    `extra_info` String,
    `rule_id` Int64,
    `bonus_type` UInt16,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
