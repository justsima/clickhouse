CREATE TABLE IF NOT EXISTS analytics.`marketing_utmurl`
(
    `id` Int64,
    `base_url` String,
    `full_url` String,
    `created_at` DateTime64(6, 'UTC'),
    `campaign_id` Int64,
    `content_id` Int64 DEFAULT 0,
    `created_by_id` Int32 DEFAULT 0,
    `medium_id` Int64 DEFAULT 0,
    `source_id` Int64,
    `term_id` Int64 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
