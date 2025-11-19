CREATE TABLE IF NOT EXISTS analytics.`crm_stat`
(
    `id` Int64,
    `total_withdraw_count` Int32,
    `total_withdraw_amount` Decimal64(2),
    `total_branch_withdraw_count` Int32,
    `total_branch_withdraw_amount` Decimal64(2),
    `total_online_withdraw_count` Int32,
    `total_online_withdraw_amount` Decimal64(2),
    `total_deposit_count` Int32,
    `total_deposit_amount` Decimal64(2),
    `total_branch_deposit_count` Int32,
    `total_branch_deposit_amount` Decimal64(2),
    `total_online_deposit_count` Int32,
    `total_online_deposit_amount` Decimal64(2),
    `total_bet_count` Int32,
    `total_bet_amount` Decimal64(2),
    `total_won_count` Int32,
    `total_won_amount` Decimal64(2),
    `total_lost_count` Int32,
    `total_lost_amount` Decimal64(2),
    `total_sent_count` Int32,
    `total_sent_amount` Decimal64(2),
    `withdraw_to_deposit_ratio` Float64,
    `deposit_to_bet_ratio` Float64,
    `won_to_lost_ration` Float64,
    `transaction_week` Date,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `user_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
