CREATE TABLE IF NOT EXISTS analytics.`flatlog_useragentinformation`
(
    `id` Int64,
    `browser` String,
    `os` String,
    `device_info` String,
    `device_type` LowCardinality(String),
    `remote_addr` String,
    `user_type` UInt16,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `user_id` Int32,
    `device_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
