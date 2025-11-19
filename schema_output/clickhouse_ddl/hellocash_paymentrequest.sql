CREATE TABLE IF NOT EXISTS analytics.`hellocash_paymentrequest`
(
    `id` Int32,
    `useridentifier` String,
    `tracenumber` Int32 DEFAULT 0,
    `status` LowCardinality(String),
    `payment_type` LowCardinality(String),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `amount` Decimal64(2),
    `hellocash_status` LowCardinality(String),
    `hellocash_id` Int32 DEFAULT 0,
    `bank` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
