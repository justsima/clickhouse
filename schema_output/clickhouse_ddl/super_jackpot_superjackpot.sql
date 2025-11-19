CREATE TABLE IF NOT EXISTS analytics.`super_jackpot_superjackpot`
(
    `id` Int64,
    `title` String,
    `description` String,
    `banner` String DEFAULT '',
    `jackpot_id` Int32,
    `start_time` DateTime64(6, 'UTC'),
    `end_time` DateTime64(6, 'UTC'),
    `stake` Float64,
    `status` Int32,
    `supported_mode` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `created_by_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
