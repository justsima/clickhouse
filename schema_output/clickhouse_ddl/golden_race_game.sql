CREATE TABLE IF NOT EXISTS analytics.`golden_race_game`
(
    `id` Int64,
    `game_id` Int32,
    `game_friendly_name` String,
    `game_title` String,
    `provider` String,
    `thumbnail` String,
    `type` LowCardinality(String),
    `sub_type` LowCardinality(String),
    `jurisdictions` String,
    `platforms` String,
    `languages` String,
    `laucher_hostname` String DEFAULT '',
    `status` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `featured` Bool,
    `order` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
