CREATE TABLE IF NOT EXISTS analytics.`flatodd_betgroup`
(
    `id` Int32,
    `name` String,
    `template` String DEFAULT '',
    `order` Int32,
    `hasParam` Bool,
    `is_active` Bool,
    `brief_odd` Bool,
    `source` Int32,
    `disabled` Bool,
    `sourceID` String DEFAULT '',
    `compatability` UInt16,
    `is_locked` Bool,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `is_print_available` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
