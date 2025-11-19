CREATE TABLE IF NOT EXISTS analytics.`casinocashback_casinocashback`
(
    `id` Int64,
    `paid_amount` Decimal(10,2),
    `ggr` Decimal(10,2),
    `original_cashback` Decimal(10,2),
    `percentage` Decimal(5,2),
    `paid_out` Bool,
    `created_at` Date,
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
