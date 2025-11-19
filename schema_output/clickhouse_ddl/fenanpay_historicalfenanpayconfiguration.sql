CREATE TABLE IF NOT EXISTS analytics.`fenanpay_historicalfenanpayconfiguration`
(
    `id` Int32,
    `configuration_ptr_id` Int32 DEFAULT 0,
    `config_name` String,
    `updated_at` DateTime64(6, 'UTC'),
    `created_at` DateTime64(6, 'UTC'),
    `api_key` String DEFAULT '',
    `withdrawal_api_key` String DEFAULT '',
    `base_url` String,
    `webhook_pubk_prod` String DEFAULT '',
    `deposit_return_url` String DEFAULT '',
    `deposit_callback_url` String DEFAULT '',
    `withdrawal_return_url` String DEFAULT '',
    `withdrawal_callback_url` String DEFAULT '',
    `is_active` Bool,
    `history_id` Int32,
    `history_date` DateTime64(6, 'UTC'),
    `history_change_reason` String DEFAULT '',
    `history_type` LowCardinality(String),
    `history_user_id` Int32 DEFAULT 0,
    `commission_paid_by_customer` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`history_id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
