CREATE TABLE IF NOT EXISTS analytics.`campaign_messagejob`
(
    `id` Int64,
    `failed` Bool,
    `job_message` String DEFAULT '',
    `started_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `finished_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `job_id` Int32,
    `status` LowCardinality(String),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `message_id` Int64,
    `delivered_count` Int32,
    `failed_count` Int32,
    `failed_error_message` String DEFAULT '',
    `success_message` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
