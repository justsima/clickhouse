CREATE TABLE IF NOT EXISTS analytics.`casino_oldreport`
(
    `id` Int64,
    `year` Int32,
    `month` Int32,
    `bet_amount` Decimal(20,8),
    `payout_amount` Decimal(20,8),
    `rollback_amount` Decimal(20,8),
    `bet_count` Int32,
    `payout_count` Int32,
    `rollback_count` Int32,
    `provider_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
