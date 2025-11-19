CREATE TABLE IF NOT EXISTS analytics.`cms_ug_gamefundsinplay`
(
    `id` Int64,
    `stake_amount` Decimal64(2),
    `refund_amount` Decimal64(2),
    `funds_type` LowCardinality(String),
    `forfeit_amount` Decimal64(2),
    `base_win_amount` Decimal64(2),
    `currency_code` String,
    `bets_won_count` Int32,
    `adjustment_amount` Decimal64(2),
    `free_stake_amount` Decimal64(2),
    `free_refund_amount` Decimal64(2),
    `bets_placed_count` Int32,
    `slips_issued_count` Int32,
    `bets_refunded_count` Int32,
    `bets_adjusted_count` Int32,
    `slips_unclaimed_amount` Decimal64(2),
    `slips_unclaimed_count` Int32,
    `wager_amount` Nullable(Decimal64(2)),
    `jackpot_win_amount` Nullable(Decimal64(2)),
    `games_played_count` Int32 DEFAULT 0,
    `jackpot_contribution_amount` Nullable(Decimal64(2)),
    `in_play_type` LowCardinality(String),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `game_id` Int64,
    `activity_date` Date,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
