CREATE TABLE IF NOT EXISTS analytics.`wheel_spinning_reward`
(
    `id` Int64,
    `label` String,
    `label_slug` String,
    `reward_type` LowCardinality(String),
    `probability` Float64,
    `color` String,
    `description` String DEFAULT '',
    `status` LowCardinality(String),
    `reward_detail` String,
    `range_start` Int32 DEFAULT 0,
    `range_end` Int32 DEFAULT 0,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `wheel_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
