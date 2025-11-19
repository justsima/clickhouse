CREATE TABLE IF NOT EXISTS analytics.`flatodd_item`
(
    `id` Int32,
    `param` String,
    `bet_group_id` Int32,
    `match_id` Int32,
    `disabled` Bool,
    `source` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `sourceID` String DEFAULT '',
    `specifier` String,
    `status` Int16,
    `gamepick_count` Int32,
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
