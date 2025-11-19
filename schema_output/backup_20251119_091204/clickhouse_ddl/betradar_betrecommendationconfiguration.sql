CREATE TABLE IF NOT EXISTS analytics.`betradar_betrecommendationconfiguration`
(
    `max_matches_to_fetch` String,
    `min_matches_per_slip` String,
    `max_matches_per_slip` String,
    `num_of_slips` String,
    `precompute_slips_count` String,
    `slips_refresh_minutes` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY tuple()
SETTINGS index_granularity = 8192;
