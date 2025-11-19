CREATE TABLE IF NOT EXISTS analytics.`flatloyality_loyalitconfiguration`
(
    `configuration_ptr_id` Int32,
    `enable_loyality_program` Bool,
    `conversion_threshold` Float64,
    `currency_to_point_conversion_rate` Float64,
    `point_to_currency_conversion_rate` Float64,
    `balance_type` Int32,
    `promotion_description_id` Int32 DEFAULT 0,
    `send_sms_on_award` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
