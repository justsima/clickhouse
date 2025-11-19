CREATE TABLE IF NOT EXISTS analytics.`onlineagent_config`
(
    `configuration_ptr_id` Int32,
    `commission_calculator` UInt16,
    `daily_per_user_deposit_amount` Nullable(Decimal64(2)),
    `daily_per_user_deposit_count` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
