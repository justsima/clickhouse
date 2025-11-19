CREATE TABLE IF NOT EXISTS analytics.`dashboardalt_transaction`
(
    `id` Int64,
    `total_sales` Float64,
    `sales_count` Int32,
    `total_payout` Float64,
    `payout_count` Int32,
    `before_0` Float64,
    `before_01` Float64,
    `after_0` Float64,
    `total_deposits` Float64,
    `deposit_count` Int32,
    `total_withdraws` Float64,
    `withdraws_count` Int32,
    `transaction_date` Date,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `branch_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
