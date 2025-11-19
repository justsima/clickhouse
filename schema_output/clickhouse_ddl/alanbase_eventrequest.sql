CREATE TABLE IF NOT EXISTS analytics.`alanbase_eventrequest`
(
    `id` Int64,
    `click_id` Int32,
    `parameters` String DEFAULT '',
    `status` LowCardinality(String),
    `value` Int32 DEFAULT 0,
    `response` String DEFAULT '',
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `event` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
