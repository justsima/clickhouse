CREATE TABLE IF NOT EXISTS analytics.`super_jackpot_superjackpotevent`
(
    `id` Int64,
    `order` Int32,
    `is_reserve` Bool,
    `result_updated_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `result` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `event_id` Int32,
    `super_jackpot_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
