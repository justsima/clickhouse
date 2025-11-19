CREATE TABLE IF NOT EXISTS analytics.`santimpay_historicalwithdrawbank`
(
    `id` Int64,
    `code` String,
    `name` String,
    `status` UInt16,
    `integration_type` UInt16,
    `transaction_fee` Float64,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `history_id` Int32,
    `history_date` DateTime64(6, 'UTC'),
    `history_change_reason` String DEFAULT '',
    `history_type` LowCardinality(String),
    `history_user_id` Int32 DEFAULT 0,
    `order` Int32,
    `identifier_type` LowCardinality(String),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`history_id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
