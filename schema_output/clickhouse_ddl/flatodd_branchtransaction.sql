CREATE TABLE IF NOT EXISTS analytics.`flatodd_branchtransaction`
(
    `id` Int32,
    `transaction_type` LowCardinality(String),
    `transaction_date` DateTime64(6, 'UTC'),
    `branch_id` Int32 DEFAULT 0,
    `sales_id` Int32,
    `wallet_id` Int32,
    `amount` Decimal64(2),
    `cancelled` Bool,
    `branch_amount` Decimal64(2),
    `transaction_fee` Float64,
    `deductable` Float64,
    `nonwithdrawable` Float64,
    `payable` Float64,
    `plan` UInt16,
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
