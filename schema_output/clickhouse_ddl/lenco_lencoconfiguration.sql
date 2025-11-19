CREATE TABLE IF NOT EXISTS analytics.`lenco_lencoconfiguration`
(
    `configuration_ptr_id` Int32,
    `public_key` String,
    `base_url` String,
    `api_token` String,
    `email` String DEFAULT '',
    `currency` String,
    `bearer` String,
    `accountId` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
