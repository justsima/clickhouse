CREATE TABLE IF NOT EXISTS analytics.`digimoney_paymentrequest`
(
    `id` Int32,
    `amount` Decimal64(2),
    `useridentifier` String,
    `referenceID` String,
    `status` LowCardinality(String),
    `payment_type` LowCardinality(String),
    `bank` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `cleared_amount` Nullable(Decimal64(2)),
    `mobile_location` String,
    `payment_method` UInt16 DEFAULT 0,
    `has_error` Bool,
    `transactionID` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
