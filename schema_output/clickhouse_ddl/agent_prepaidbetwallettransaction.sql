CREATE TABLE IF NOT EXISTS analytics.`agent_prepaidbetwallettransaction`
(
    `id` Int32,
    `amount` Decimal64(2),
    `status` UInt16,
    `transaction_type` UInt16,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `reason` UInt16,
    `reference` String,
    `remark` String,
    `payment_method` String,
    `transaction_by_id` Int32 DEFAULT 0,
    `wallet_id` Int32,
    `before_balance` Decimal64(2),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
