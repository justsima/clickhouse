CREATE TABLE IF NOT EXISTS analytics.`freshpay_freshpayconfiguration`
(
    `configuration_ptr_id` Int32,
    `base_url` String,
    `currency` String,
    `merchant_id` Int32 DEFAULT 0,
    `merchant_secret` String DEFAULT '',
    `merchant_first_name` String DEFAULT '',
    `merchant_last_name` String DEFAULT '',
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
