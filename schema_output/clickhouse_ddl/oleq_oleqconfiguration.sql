CREATE TABLE IF NOT EXISTS analytics.`oleq_oleqconfiguration`
(
    `configuration_ptr_id` Int32,
    `country_code` Int32,
    `api_key` String DEFAULT '',
    `auth_key` String DEFAULT '',
    `b2c_short_code` String DEFAULT '',
    `c2b_short_code` String DEFAULT '',
    `base_url` String,
    `b2c_callback_url` String,
    `c2b_callback_url` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
