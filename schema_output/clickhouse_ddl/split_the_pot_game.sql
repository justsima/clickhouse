CREATE TABLE IF NOT EXISTS analytics.`split_the_pot_game`
(
    `id` Int64,
    `game_id` Int32,
    `game_kind` String,
    `game_variant` String,
    `title` String,
    `enabled` Bool,
    `maintenance` Bool,
    `url` String,
    `free_to_play_url` String,
    `bet_history_url` String,
    `square_x3` String DEFAULT '',
    `wide_x` String DEFAULT '',
    `status` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
