CREATE TABLE IF NOT EXISTS analytics.`flatodd_offlinecoupongamepick`
(
    `id` Int32,
    `odd` Float64,
    `refund` Float64,
    `odd_id` Int32,
    `status` LowCardinality(String),
    `bet_group_id` Int32,
    `bet_type_id` Int32,
    `coupon_id` Int32,
    `item_id` Int32,
    `match_id` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `is_active` Bool,
    `result` Int16 DEFAULT 0,
    `void_factor` Decimal(2,1) DEFAULT 0,
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
