CREATE TABLE IF NOT EXISTS analytics.`superjackpot_jackpot`
(
    `id` Int32,
    `title` String,
    `description` String,
    `stake` Float64,
    `start_time` DateTime64(6, 'UTC'),
    `end_time` DateTime64(6, 'UTC'),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `status` Int32,
    `result_updated_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `banner` String DEFAULT '',
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
