CREATE TABLE IF NOT EXISTS analytics.`arifpay_historicalarifpayconfiguration`
(
    `id` Int32,
    `configuration_ptr_id` Int32 DEFAULT 0,
    `config_name` String,
    `updated_at` DateTime64(6, 'UTC'),
    `created_at` DateTime64(6, 'UTC'),
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
    `history_id` Int32,
    `history_date` DateTime64(6, 'UTC'),
    `history_change_reason` String DEFAULT '',
    `history_type` LowCardinality(String),
    `history_user_id` Int32 DEFAULT 0,
    `is_active` Bool,
    `merchant_name` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`history_id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
