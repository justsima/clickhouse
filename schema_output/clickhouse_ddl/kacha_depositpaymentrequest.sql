CREATE TABLE IF NOT EXISTS analytics.`kacha_depositpaymentrequest`
(
    `id` Int64,
    `amount` Decimal64(2),
    `fee` Float64 DEFAULT 0.0,
    `useridentifier` String,
    `kacha_id` Int32,
    `kacha_status` LowCardinality(String),
    `comment` String,
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `transaction_id` Int32,
    `tracenumber` Int32,
    `status` UInt16,
    `kacha_otp` String,
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `kacha_reference` String,
    `kacha_user_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
