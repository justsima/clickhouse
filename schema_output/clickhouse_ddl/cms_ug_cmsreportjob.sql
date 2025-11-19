CREATE TABLE IF NOT EXISTS analytics.`cms_ug_cmsreportjob`
(
    `id` Int64,
    `report_start_date` DateTime64(6, 'UTC'),
    `report_end_date` DateTime64(6, 'UTC'),
    `failed` Bool,
    `job_iteration` Int32,
    `package_name` String,
    `messages` String DEFAULT '',
    `started_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `finished_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `job_id` Int32,
    `package_id` Int32 DEFAULT 0,
    `job_status` LowCardinality(String),
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
