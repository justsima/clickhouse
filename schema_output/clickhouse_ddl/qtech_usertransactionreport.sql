CREATE TABLE IF NOT EXISTS analytics.`qtech_usertransactionreport`
(
    `id` Int64,
    `date` DateTime64(6, 'UTC'),
    `total_bet_amount` Decimal64(2),
    `total_bet_count` Int32,
    `total_payout_amount` Decimal64(2),
    `total_payout_count` Int32,
    `total_rollback_amount` Decimal64(2),
    `total_rollback_count` Int32,
    `ggr` Float64,
    `ggr_percent` Float64,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `user_id` Int32,
    `total_bet_tax_amount` Decimal64(2),
    `total_payout_tax_amount` Decimal64(2),
    `total_rollback_tax_amount` Decimal64(2),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
