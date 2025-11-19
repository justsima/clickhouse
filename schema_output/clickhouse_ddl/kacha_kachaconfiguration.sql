CREATE TABLE IF NOT EXISTS analytics.`kacha_kachaconfiguration`
(
    `configuration_ptr_id` Int32,
    `shortcode` String,
    `password` String,
    `username` String,
    `base_url` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
