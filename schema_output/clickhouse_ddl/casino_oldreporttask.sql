CREATE TABLE IF NOT EXISTS analytics.`casino_oldreporttask`
(
    `id` Int64,
    `type` LowCardinality(String),
    `year` Int32,
    `month` Int32,
    `status` LowCardinality(String),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `completed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `error_message` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
