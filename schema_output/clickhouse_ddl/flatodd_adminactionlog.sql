CREATE TABLE IF NOT EXISTS analytics.`flatodd_adminactionlog`
(
    `id` Int32,
    `action_type` LowCardinality(String),
    `model_name` String,
    `object_id` Int32 DEFAULT 0,
    `description` String,
    `ip_address` String DEFAULT '',
    `user_agent` String DEFAULT '',
    `metadata` String,
    `created_at` DateTime64(6, 'UTC'),
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
