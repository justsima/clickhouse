CREATE TABLE IF NOT EXISTS analytics.`casinocashback_casinocashbackconfiguration`
(
    `id` Int64,
    `frequency` String,
    `percentage` Decimal(5,2),
    `is_active` Bool,
    `start_date` DateTime64(6, 'UTC'),
    `end_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `enable_sms` Bool,
    `wallet_type` LowCardinality(String),
    `on_cancel_option` String,
    `minimum_loss` Decimal(12,2),
    `maximum_cashback` Decimal(12,2),
    `next_start_date` Date DEFAULT toDate(0),
    `next_end_date` Date DEFAULT toDate(0),
    `created_at` Date,
    `updated_at` DateTime64(6, 'UTC'),
    `created_by_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`start_date`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
