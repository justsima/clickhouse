CREATE TABLE IF NOT EXISTS analytics.`flatodd_banktransaction`
(
    `id` Int32,
    `amount` Decimal64(2),
    `bank` String,
    `transaction_type` LowCardinality(String),
    `status` LowCardinality(String),
    `wallet_id` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `transaction_fee` Float64,
    `reason` String,
    `is_payable` Bool,
    `updated_at` DateTime64(6, 'UTC'),
    `deductable` Float64,
    `nonwithdrawable` Float64,
    `payable` Float64,
    `approved_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `deposit_by_id` Int32 DEFAULT 0,
    `beneficiary_user_type` UInt16,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
