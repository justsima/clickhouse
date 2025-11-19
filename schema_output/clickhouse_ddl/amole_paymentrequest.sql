CREATE TABLE IF NOT EXISTS analytics.`amole_paymentrequest`
(
    `id` Int64,
    `payment_type` UInt16,
    `state` UInt16,
    `amount` Decimal64(2),
    `comment` String DEFAULT '',
    `uuid` UUID,
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32 DEFAULT 0,
    `user_id` Int32,
    `useridentifier` String,
    `otp` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
