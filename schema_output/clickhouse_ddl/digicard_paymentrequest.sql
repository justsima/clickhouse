CREATE TABLE IF NOT EXISTS analytics.`digicard_paymentrequest`
(
    `id` Int64,
    `amount` Decimal64(2),
    `referenceID` String,
    `payment_type` UInt16,
    `status` UInt16,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `user_id` Int32,
    `bank_transaction_id` Int32,
    `cleared_amount` Nullable(Decimal64(2)),
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `external_id` Int32,
    `source_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
