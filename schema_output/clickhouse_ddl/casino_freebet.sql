CREATE TABLE IF NOT EXISTS analytics.`casino_freebet`
(
    `id` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `status` Int32,
    `idn` String,
    `start_date` DateTime64(6, 'UTC'),
    `end_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `unit_value` Decimal(20,8),
    `quantity` Int32,
    `provider_transaction_reference` String DEFAULT '',
    `game_id` Int32,
    `member_id` Int32,
    `provider_id` Int32 DEFAULT 0,
    `wallet_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
