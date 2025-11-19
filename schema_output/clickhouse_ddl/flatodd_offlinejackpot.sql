CREATE TABLE IF NOT EXISTS analytics.`flatodd_offlinejackpot`
(
    `id` Int32,
    `paid_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `is_paid` Bool,
    `created_at` DateTime64(6, 'UTC'),
    `won_status` LowCardinality(String),
    `coupon_id` Int32,
    `receiptID` String,
    `confirmed_by_id` Int32 DEFAULT 0,
    `confirmed_on` DateTime64(6, 'UTC'),
    `cancelled` Bool,
    `cancelled_on` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `branch_id` Int32,
    `paid_by_id` Int32 DEFAULT 0,
    `cancelled_by_id` Int32 DEFAULT 0,
    `printed` Bool,
    `paid_amount` Decimal64(2),
    `payable_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `status` LowCardinality(String),
    `compatability` UInt16,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
