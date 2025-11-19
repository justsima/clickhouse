CREATE TABLE IF NOT EXISTS analytics.`casinocashback_casinocashbacksummary`
(
    `id` Int64,
    `total_cashback_paid` Decimal(10,2),
    `total_ggr` Decimal(23,2),
    `frequency` String,
    `percentage` Decimal(5,2),
    `members_count` Int32,
    `date_range_start` Date DEFAULT toDate(0),
    `date_range_end` Date DEFAULT toDate(0),
    `created_at` Date,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
