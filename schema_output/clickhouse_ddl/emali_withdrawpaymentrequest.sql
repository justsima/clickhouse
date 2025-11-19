CREATE TABLE IF NOT EXISTS analytics.`emali_withdrawpaymentrequest`
(
    `id` Int64,
    `external_ref_no` String DEFAULT '',
    `receipt_number` Int32 DEFAULT 0,
    `transaction_datetime` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `transaction_id` Int32 DEFAULT 0,
    `useridentifier` String,
    `available_balance` Nullable(Decimal64(2)),
    `current_balance` Nullable(Decimal64(2)),
    `service_charge` Float64 DEFAULT 0.0,
    `status_code` LowCardinality(String),
    `api_user_id` Int32 DEFAULT 0,
    `message` String DEFAULT '',
    `status` Int32,
    `transaction_reference` String,
    `comment` String DEFAULT '',
    `amount` Decimal64(2),
    `committed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `transaction_type` LowCardinality(String) DEFAULT '',
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
