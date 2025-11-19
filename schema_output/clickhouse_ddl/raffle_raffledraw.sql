CREATE TABLE IF NOT EXISTS analytics.`raffle_raffledraw`
(
    `id` Int64,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `start_date` DateTime64(6, 'UTC'),
    `end_date` DateTime64(6, 'UTC'),
    `is_approved` Bool,
    `status` LowCardinality(String),
    `campaign_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
