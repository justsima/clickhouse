CREATE TABLE IF NOT EXISTS analytics.`betradar_betrecommendationconfiguration`
(
    `id` Int64,
    `min_single_odd` Decimal(5,2),
    `max_matches_to_fetch` UInt32,
    `min_matches_per_slip` UInt32,
    `max_matches_per_slip` UInt32,
    `is_active` Bool,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `num_of_slips` UInt32,
    `precompute_slips_count` UInt32,
    `slips_refresh_minutes` UInt32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
