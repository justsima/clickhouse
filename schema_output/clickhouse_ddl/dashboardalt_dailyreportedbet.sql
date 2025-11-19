CREATE TABLE IF NOT EXISTS analytics.`dashboardalt_dailyreportedbet`
(
    `id` Int64,
    `bet_date` Date,
    `gross_stake` Float64,
    `percentage` Float64,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `branch_id` Int32,
    `monthly_reported_bet_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
