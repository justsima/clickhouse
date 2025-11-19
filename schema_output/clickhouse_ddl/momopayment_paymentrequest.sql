CREATE TABLE IF NOT EXISTS analytics.`momopayment_paymentrequest`
(
    `id` Int32,
    `amount` Decimal64(2),
    `referenceID` String,
    `status` LowCardinality(String),
    `created_at` DateTime64(6, 'UTC'),
    `user_id` Int32,
    `externalID` String,
    `useridentifier` String,
    `payment_type` LowCardinality(String),
    `bank_transaction_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
