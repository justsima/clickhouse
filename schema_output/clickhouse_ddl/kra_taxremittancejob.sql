CREATE TABLE IF NOT EXISTS analytics.`kra_taxremittancejob`
(
    `id` Int64,
    `tax_start_date` Date,
    `tax_end_date` Date,
    `failed` Bool,
    `messages` String DEFAULT '',
    `prn_payload` String DEFAULT '',
    `started_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `finished_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `job_id` Int32,
    `tax_type` LowCardinality(String),
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
