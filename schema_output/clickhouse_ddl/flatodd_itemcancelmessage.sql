CREATE TABLE IF NOT EXISTS analytics.`flatodd_itemcancelmessage`
(
    `id` Int32,
    `start_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `end_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `is_rolled_back` Bool,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `item_id` Int32,
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
