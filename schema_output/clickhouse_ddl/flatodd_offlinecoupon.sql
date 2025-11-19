CREATE TABLE IF NOT EXISTS analytics.`flatodd_offlinecoupon`
(
    `id` Int32,
    `stake` Float64,
    `possible_win` Float64,
    `couponID` String,
    `created_at` DateTime64(6, 'UTC'),
    `printed` Bool,
    `channel` String,
    `printed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
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
