CREATE TABLE IF NOT EXISTS analytics.`crm_customercategory`
(
    `total_deposit_date` String,
    `total_withdraw_date` String,
    `total_bet_date` String,
    `total_won_date` String,
    `withdraw_to_deposit_ratio_date` String,
    `deposit_to_bet_ratio_date` String,
    `won_to_lost_ration_date` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY tuple()
SETTINGS index_granularity = 8192;
