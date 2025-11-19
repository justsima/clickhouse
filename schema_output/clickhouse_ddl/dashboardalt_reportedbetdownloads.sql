CREATE TABLE IF NOT EXISTS analytics.`dashboardalt_reportedbetdownloads`
(
    `id` Int64,
    `filters` String,
    `field_names` String,
    `csv_file_path` String DEFAULT '',
    `download_id` Int32,
    `download_status` LowCardinality(String),
    `started_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `finished_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `messages` String DEFAULT '',
    `failed` Bool,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `file_name` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
