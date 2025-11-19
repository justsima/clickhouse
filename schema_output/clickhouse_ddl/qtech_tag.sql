CREATE TABLE IF NOT EXISTS analytics.`qtech_tag`
(
    `id` Int64,
    `name` String,
    `order` Int32,
    `logo` String DEFAULT '',
    `is_shown_on_lobby` Bool,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `status` UInt16,
    `phone_template` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
