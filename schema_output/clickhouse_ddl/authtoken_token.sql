CREATE TABLE IF NOT EXISTS analytics.`authtoken_token`
(
    `key` String,
    `created` DateTime64(6, 'UTC'),
    `user_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`key`)
PARTITION BY toYYYYMM(`created`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
