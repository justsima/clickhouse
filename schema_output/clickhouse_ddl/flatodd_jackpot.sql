CREATE TABLE IF NOT EXISTS analytics.`flatodd_jackpot`
(
    `id` Int32,
    `start_time` DateTime64(6, 'UTC'),
    `end_time` DateTime64(6, 'UTC'),
    `stake` Float64,
    `possible_win` Float64,
    `name` String DEFAULT '',
    `is_active` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`start_time`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
