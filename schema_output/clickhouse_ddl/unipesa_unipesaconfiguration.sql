CREATE TABLE IF NOT EXISTS analytics.`unipesa_unipesaconfiguration`
(
    `configuration_ptr_id` Int32,
    `base_url` String,
    `public_id` Int32,
    `merchant_id` Int32,
    `secret_key` String,
    `deposit_callback_url` String DEFAULT '',
    `withdraw_callback_url` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
