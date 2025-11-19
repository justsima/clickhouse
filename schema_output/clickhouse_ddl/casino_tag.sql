CREATE TABLE IF NOT EXISTS analytics.`casino_tag`
(
    `id` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `name` String,
    `description` String DEFAULT '',
    `logo` String DEFAULT '',
    `order` Int32,
    `template` String,
    `slug` String DEFAULT '',
    `display_on` String,
    `sport_book_order` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
