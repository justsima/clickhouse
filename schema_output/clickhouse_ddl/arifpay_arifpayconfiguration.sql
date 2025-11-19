CREATE TABLE IF NOT EXISTS analytics.`arifpay_arifpayconfiguration`
(
    `configuration_ptr_id` Int32,
    `email` String DEFAULT '',
    `api_key` String DEFAULT '',
    `base_url` String,
    `direct_deposit_base_url` String,
    `deposit_error_url` String DEFAULT '',
    `deposit_success_url` String DEFAULT '',
    `deposit_failure_url` String DEFAULT '',
    `deposit_notification_url` String DEFAULT '',
    `withdraw_error_url` String DEFAULT '',
    `withdraw_success_url` String DEFAULT '',
    `withdraw_failure_url` String DEFAULT '',
    `withdraw_notification_url` String DEFAULT '',
    `is_active` Bool,
    `merchant_name` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
