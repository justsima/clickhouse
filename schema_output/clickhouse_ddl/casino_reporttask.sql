CREATE TABLE IF NOT EXISTS analytics.`casino_reporttask`
(
    `id` Int64,
    `status` Int32,
    `report_type` Int32,
    `amount` Decimal(20,8),
    `amount_after_tax` Nullable(Decimal(20,8)),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bet_id` Int32 DEFAULT 0,
    `payout_id` Int32 DEFAULT 0,
    `rollback_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
