CREATE TABLE IF NOT EXISTS analytics.`django_migrations`
(
    `id` Int32,
    `app` String,
    `name` String,
    `applied` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`applied`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
