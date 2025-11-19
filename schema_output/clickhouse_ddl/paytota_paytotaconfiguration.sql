CREATE TABLE IF NOT EXISTS analytics.`paytota_paytotaconfiguration`
(
    `configuration_ptr_id` Int32,
    `base_url` String,
    `country_code` Int32,
    `auth_key` String DEFAULT '',
    `b2c_short_code` String DEFAULT '',
    `c2b_short_code` String DEFAULT '',
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
