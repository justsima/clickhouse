CREATE TABLE IF NOT EXISTS analytics.`telebirr_paymentrequest`
(
    `id` Int64,
    `amount` Decimal64(2),
    `state` UInt16,
    `payment_type` LowCardinality(String),
    `useridentifier` String,
    `uuid` UUID,
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `comment` String,
    `telebirr_status` UInt16,
    `trade_no` String,
    `transaction_no` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
