CREATE TABLE IF NOT EXISTS analytics.`santimpay_santimpayconfiguration`
(
    `configuration_ptr_id` Int32,
    `merchant_id` Int32 DEFAULT 0,
    `base_url` String DEFAULT '',
    `site_id` Int32 DEFAULT 0,
    `gateway_token` String DEFAULT '',
    `private_key` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
