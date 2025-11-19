CREATE TABLE IF NOT EXISTS analytics.`super_jackpot_onlinesuperjackpotticketpick`
(
    `id` Int64,
    `status` Int32,
    `pick` Int32,
    `is_reserve` Bool,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `event_id` Int64,
    `ticket_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
