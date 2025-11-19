CREATE TABLE IF NOT EXISTS analytics.`auth_user`
(
    `id` Int32,
    `password` String,
    `last_login` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `is_superuser` Bool,
    `username` String,
    `first_name` String,
    `last_name` String,
    `email` String,
    `is_staff` Bool,
    `is_active` Bool,
    `date_joined` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`date_joined`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
