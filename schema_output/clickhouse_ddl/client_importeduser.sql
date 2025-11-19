CREATE TABLE IF NOT EXISTS analytics.`client_importeduser`
(
    `id` Int32,
    `password` String,
    `file_name` String,
    `phone_number` Int32,
    `user_created` Bool,
    `first_name` String DEFAULT '',
    `last_name` String DEFAULT '',
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `tag_id` Int32 DEFAULT 0,
    `import_task_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
