CREATE TABLE IF NOT EXISTS analytics.`bonus_wageringpolicy`
(
    `id` String,
    `min_stake` Float64 DEFAULT 0.0,
    `min_total_odd` Float64 DEFAULT 0.0,
    `min_individual_odd` Float64 DEFAULT 0.0,
    `min_number_of_matches` Int32 DEFAULT 0,
    `max_contribution_amount` Nullable(Decimal64(2)),
    `max_contribution_type` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `title` String,
    `min_individual_odd_eligibility_criteria` Int32,
    `max_payout` Float64 DEFAULT 0.0,
    `min_deposit_amount` Nullable(Decimal64(2)),
    `contribution_tracking_source` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
