CREATE TABLE IF NOT EXISTS analytics.`fenanpay_fenanpayconfiguration`
(
    `configuration_ptr_id` Int32,
    `api_key` String DEFAULT '',
    `withdrawal_api_key` String DEFAULT '',
    `base_url` String,
    `webhook_pubk_prod` String DEFAULT '',
    `deposit_return_url` String DEFAULT '',
    `deposit_callback_url` String DEFAULT '',
    `withdrawal_return_url` String DEFAULT '',
    `withdrawal_callback_url` String DEFAULT '',
    `is_active` Bool,
    `commission_paid_by_customer` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
