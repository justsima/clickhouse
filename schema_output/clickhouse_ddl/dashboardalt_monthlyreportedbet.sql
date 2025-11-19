CREATE TABLE IF NOT EXISTS analytics.`dashboardalt_monthlyreportedbet`
(
    `id` Int64,
    `month_year` String,
    `gross_stake` Float64,
    `before_tax` Float64,
    `total_tax` Float64,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `branch_id` Int32,
    `generated_stake` Float64,
    `actual_stake` Float64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
