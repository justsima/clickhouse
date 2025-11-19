CREATE TABLE IF NOT EXISTS analytics.`casino_game`
(
    `id` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `slug` String DEFAULT '',
    `game_id` Int32,
    `content_server_id` Int32,
    `name` String,
    `description` String,
    `label` String DEFAULT '',
    `label_background` String DEFAULT '',
    `order` Int32,
    `default_logo` String DEFAULT '',
    `logo` String DEFAULT '',
    `enabled` Bool,
    `content_server_enabled` Bool,
    `demo_support` Bool,
    `free_bet_supported` Bool,
    `free_bet_cancellation_supported` Bool,
    `launcher_url` String DEFAULT '',
    `supports_multiple_payout` Bool,
    `provider_id` Int32,
    `demo_url` String DEFAULT '',
    `desktop_device_support` Bool,
    `mobile_device_support` Bool,
    `seo_description` String DEFAULT '',
    `seo_image` String DEFAULT '',
    `seo_keywords` String DEFAULT '',
    `seo_title` String DEFAULT '',
    `spribe_provider_key` String DEFAULT '',
    `weight` Decimal(10,4),
    `instance_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
