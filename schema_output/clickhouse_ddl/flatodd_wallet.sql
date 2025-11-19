CREATE TABLE IF NOT EXISTS analytics.`flatodd_wallet`
(
    `id` Int32,
    `balance` Decimal64(2),
    `is_active` Bool,
    `owner_id` Int32,
    `payable` Float64,
    `nonwithdrawable` Float64,
    `last_wallet_changed_at` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`last_wallet_changed_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
