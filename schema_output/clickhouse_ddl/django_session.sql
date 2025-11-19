CREATE TABLE IF NOT EXISTS analytics.`django_session`
(
    `session_key` String,
    `session_data` String,
    `expire_date` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`session_key`)
PARTITION BY toYYYYMM(`expire_date`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
