CREATE TABLE IF NOT EXISTS analytics.`qtech_game`
(
    `id` Int64,
    `game_id` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `category_id` Int64,
    `currencies` String,
    `demo_support` Bool,
    `description` String,
    `desktop_device_support` Bool,
    `features` String,
    `free_round_support` Bool,
    `images` String,
    `languages` String,
    `mobile_device_support` Bool,
    `themes` String,
    `volatility` String,
    `status` UInt16,
    `name` String,
    `provider_id` Int64,
    `is_featured` Bool,
    `order` Int32,
    `logo` String DEFAULT '',
    `featured_online` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
