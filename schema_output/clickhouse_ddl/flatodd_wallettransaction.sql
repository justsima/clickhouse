CREATE TABLE IF NOT EXISTS analytics.`flatodd_wallettransaction`
(
    `id` Int32,
    `transaction_date` DateTime64(6, 'UTC'),
    `from_wallet_id` Int32,
    `to_wallet_id` Int32,
    `amount` Decimal64(2),
    `from_payable` Float64,
    `to_payable` Float64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`transaction_date`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
