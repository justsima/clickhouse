CREATE TABLE IF NOT EXISTS analytics.`betradar_betrecommendationconfiguration_main_markets`
(
    `id` Int32,
    `betrecommendationconfiguration_id` Int64,
    `betgroup_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
