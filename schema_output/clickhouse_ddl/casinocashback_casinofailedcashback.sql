CREATE TABLE IF NOT EXISTS analytics.`casinocashback_casinofailedcashback`
(
    `id` Int64,
    `amount` Decimal(10,2),
    `percentage` Decimal(5,2),
    `error_message` String,
    `created_at` Date,
    `resolved` Bool,
    `resolved_at` Date DEFAULT toDate(0),
    `date_range_start` Date DEFAULT toDate(0),
    `date_range_end` Date DEFAULT toDate(0),
    `config_id` Int64,
    `member_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
