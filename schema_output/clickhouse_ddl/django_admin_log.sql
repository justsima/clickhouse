CREATE TABLE IF NOT EXISTS analytics.`django_admin_log`
(
    `id` Int32,
    `action_time` DateTime64(6, 'UTC'),
    `object_id` Int32 DEFAULT 0,
    `object_repr` String,
    `action_flag` UInt16,
    `change_message` String,
    `content_type_id` Int32 DEFAULT 0,
    `user_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`action_time`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
