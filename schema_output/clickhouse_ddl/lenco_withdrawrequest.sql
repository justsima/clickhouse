CREATE TABLE IF NOT EXISTS analytics.`lenco_withdrawrequest`
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
    `account_id` Int32,
    `account_name` Int32,
    `account_number` Int32,
    `transfer_type` LowCardinality(String),
    `narration` String DEFAULT '',
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
