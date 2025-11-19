CREATE TABLE IF NOT EXISTS analytics.`sales_dailycashflowbalance`
(
    `id` Int32,
    `offlinebet_cashin` Decimal(10,2),
    `balance_date` Date,
    `offlinebet_cashin_last` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `branch_id` Int32,
    `sales_id` Int32,
    `deposit_cashin` Decimal(10,2),
    `deposit_cashin_last` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
