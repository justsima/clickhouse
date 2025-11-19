CREATE TABLE IF NOT EXISTS analytics.`casino_gameprovider`
(
    `id` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `provider_id` Int32,
    `idn` String,
    `slug` String DEFAULT '',
    `name` String,
    `description` String,
    `order` Int32,
    `default_logo` String DEFAULT '',
    `logo` String DEFAULT '',
    `enabled` Bool,
    `aggregator_id` Int32 DEFAULT 0,
    `content_server_enabled` Bool,
    `seo_description` String DEFAULT '',
    `seo_image` String DEFAULT '',
    `seo_keywords` String DEFAULT '',
    `seo_title` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
