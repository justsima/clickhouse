CREATE TABLE IF NOT EXISTS analytics.`sport_bespoke_reports`
(
    `id` Int64,
    `date` Date,
    `bet_amount` Decimal(20,8),
    `bet_amount_after_tax` Decimal(20,8),
    `payout_amount` Decimal(20,8),
    `payout_amount_after_tax` Decimal(20,8),
    `rollback_amount` Decimal(20,8),
    `stake_tax1_amount` Decimal(20,8),
    `stake_tax2_amount` Decimal(20,8),
    `stake_tax3_amount` Decimal(20,8),
    `payout_tax1_amount` Decimal(20,8),
    `payout_tax2_amount` Decimal(20,8),
    `payout_tax3_amount` Decimal(20,8),
    `created_at` DateTime64(6, 'UTC'),
    `player_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
