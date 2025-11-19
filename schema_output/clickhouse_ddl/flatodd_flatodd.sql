CREATE TABLE IF NOT EXISTS analytics.`flatodd_flatodd`
(
    `id` Int32,
    `odd` Float64,
    `bet_group_id` Int32,
    `bet_type_id` Int32,
    `item_id` Int32,
    `status` LowCardinality(String),
    `match_id` Int32 DEFAULT 0,
    `winStatus` Int32,
    `disabled` Bool,
    `source` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `cancel_end_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `cancel_start_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `sourceID` String DEFAULT '',
    `is_active` Bool,
    `result` Int16 DEFAULT 0,
    `void_factor` Decimal(2,1) DEFAULT 0,
    `compatability` UInt16,
    `settlement_updated_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
