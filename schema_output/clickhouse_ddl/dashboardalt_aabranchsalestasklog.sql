CREATE TABLE IF NOT EXISTS analytics.`dashboardalt_aabranchsalestasklog`
(
    `id` Int64,
    `file_name` String,
    `task_id` Int32,
    `task_status` LowCardinality(String),
    `started_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `finished_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `messages` String DEFAULT '',
    `failed` Bool,
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
