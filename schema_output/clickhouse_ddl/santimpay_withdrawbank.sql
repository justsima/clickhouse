CREATE TABLE IF NOT EXISTS analytics.`santimpay_withdrawbank`
(
    `id` Int64,
    `code` String,
    `name` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `status` UInt16,
    `transaction_fee` Float64,
    `integration_type` UInt16,
    `order` Int32,
    `identifier_type` LowCardinality(String),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
