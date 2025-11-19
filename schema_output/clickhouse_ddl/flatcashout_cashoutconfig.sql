CREATE TABLE IF NOT EXISTS analytics.`flatcashout_cashoutconfig`
(
    `id` Int64,
    `min_total_odd` Float64,
    `min_stake` Float64,
    `min_indv_odd` Float64,
    `min_number_matchs` Int32,
    `won_criteria` UInt16,
    `won_criteria_value` Int32,
    `max_cashout_amount` Decimal64(2),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `amount_award_rule` UInt16,
    `amount_award_rule_value` Int32,
    `expire_time` DateTime64(6, 'UTC'),
    `is_bonus_allowed` Bool,
    `channel` UInt16,
    `status` UInt16,
    `is_abandoned_match_allowed` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
