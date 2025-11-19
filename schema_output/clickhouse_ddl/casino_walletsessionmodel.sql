CREATE TABLE IF NOT EXISTS analytics.`casino_walletsessionmodel`
(
    `id` Int64,
    `entity_id` Int32,
    `session_id` Int32,
    `player_id` Int32,
    `expires_at` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`expires_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
