CREATE TABLE IF NOT EXISTS analytics.`chappa_bank`
(
    `id` Int64,
    `name` String,
    `code` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `status` Int32,
    `transaction_fee` Float64,
    `is_mobile_meny` Bool,
    `supports_direct` Bool,
    `verification_type` LowCardinality(String),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
