CREATE TABLE IF NOT EXISTS analytics.`dashboardalt_reportedbet`
(
    `id` Int64,
    `couponID` String,
    `gross_stake` Float64,
    `stake_after_tax` Float64,
    `stake_tax` Float64,
    `number_matches` Int32,
    `has_cashback` Bool,
    `has_cashout` Bool,
    `is_won` Bool,
    `is_paid` Bool,
    `slilp_hash` String DEFAULT '',
    `match_hash` String DEFAULT '',
    `confirmed_at` DateTime64(6, 'UTC'),
    `branch_id` Int32 DEFAULT 0,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `defected` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
