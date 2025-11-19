CREATE TABLE IF NOT EXISTS analytics.`lenco_depositpaymentrequest`
(
    `id` Int64,
    `amount` Decimal64(2),
    `fee` Float64 DEFAULT 0.0,
    `lenco_id` Int32,
    `currency` String DEFAULT '',
    `reference` String,
    `lenco_reference` String DEFAULT '',
    `source` String,
    `failure_reason` String DEFAULT '',
    `comment` String DEFAULT '',
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `status` LowCardinality(String),
    `bearer` String,
    `payment_type` LowCardinality(String),
    `settlement_status` LowCardinality(String) DEFAULT '',
    `settlement_type` LowCardinality(String) DEFAULT '',
    `settlement_account_id` Int32 DEFAULT 0,
    `bank_id` Int64,
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
