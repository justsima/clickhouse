CREATE TABLE IF NOT EXISTS analytics.`harifsport_player`
(
    `id` Int64,
    `user_id` Int32,
    `username` String,
    `parent` String,
    `role` String,
    `skin` String,
    `ip` String DEFAULT '',
    `last_access` DateTime64(6, 'UTC'),
    `registration_date` DateTime64(6, 'UTC'),
    `registration_ip` String DEFAULT '',
    `bonus_balance` Decimal64(2),
    `total_valid_balance` Decimal64(2),
    `withdrawable_balance` Decimal64(2),
    `non_withdrawable_balance` Decimal64(2),
    `password` String DEFAULT '',
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
