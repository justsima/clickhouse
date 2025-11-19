CREATE TABLE IF NOT EXISTS analytics.`casino_gamecategory`
(
    `id` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `name` String,
    `description` String DEFAULT '',
    `default_logo` String DEFAULT '',
    `logo` String DEFAULT '',
    `slug` String DEFAULT '',
    `label` String DEFAULT '',
    `order` Int32,
    `status` Int32,
    `is_visible` Bool,
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
