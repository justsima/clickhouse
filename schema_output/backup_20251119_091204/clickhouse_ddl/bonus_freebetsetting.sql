CREATE TABLE IF NOT EXISTS analytics.`bonus_freebetsetting`
(
    `award_type` String,
    `activation_type` String,
    `status` String,
    `supported_platform` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY tuple()
SETTINGS index_granularity = 8192;
