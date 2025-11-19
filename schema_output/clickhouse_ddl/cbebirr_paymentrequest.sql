CREATE TABLE IF NOT EXISTS analytics.`cbebirr_paymentrequest`
(
    `id` Int64,
    `amount` Decimal64(2),
    `useridentifier` String,
    `billreferencenumber` Int32 DEFAULT 0,
    `status` LowCardinality(String),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `user_id` Int32,
    `transaction_id` Int32,
    `bank_transaction_id` Int32,
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `payment_type` UInt16,
    `cbebirr_state` UInt16,
    `queried_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `validated_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `response_desc` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
