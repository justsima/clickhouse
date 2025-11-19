CREATE TABLE IF NOT EXISTS analytics.`chappa_chapaconfiguration`
(
    `configuration_ptr_id` Int32,
    `base_url` String DEFAULT '',
    `email` String DEFAULT '',
    `secret_key` String DEFAULT '',
    `encryption_key` String DEFAULT '',
    `is_active` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
