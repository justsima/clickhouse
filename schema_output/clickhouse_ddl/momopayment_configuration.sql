CREATE TABLE IF NOT EXISTS analytics.`momopayment_configuration`
(
    `id` Int32,
    `key` String,
    `value` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
