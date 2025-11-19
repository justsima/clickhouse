CREATE TABLE IF NOT EXISTS analytics.`crm_customercategory`
(
    `id` Int64,
    `category_name` LowCardinality(String),
    `last_bet` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `last_deposit` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `last_withdrawal` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `last_won` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `total_deposit_date` UInt16 DEFAULT 0,
    `total_deposit_amount_min` Nullable(Decimal64(2)),
    `total_deposit_amount_max` Nullable(Decimal64(2)),
    `total_withdraw_date` UInt16 DEFAULT 0,
    `total_withdraw_amount_min` Nullable(Decimal64(2)),
    `total_withdraw_amount_max` Nullable(Decimal64(2)),
    `total_bet_date` UInt16 DEFAULT 0,
    `total_bet_amount_min` Nullable(Decimal64(2)),
    `total_bet_amount_max` Nullable(Decimal64(2)),
    `total_won_date` UInt16 DEFAULT 0,
    `total_won_amount_min` Nullable(Decimal64(2)),
    `total_won_amount_max` Nullable(Decimal64(2)),
    `withdraw_to_deposit_ratio_date` UInt16 DEFAULT 0,
    `withdraw_to_deposit_ratio` Float64,
    `deposit_to_bet_ratio_date` UInt16 DEFAULT 0,
    `deposit_to_bet_ratio` Float64,
    `won_to_lost_ration_date` UInt16 DEFAULT 0,
    `won_to_lost_ration` Float64,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
