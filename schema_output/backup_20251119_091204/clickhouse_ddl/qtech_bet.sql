CREATE TABLE IF NOT EXISTS analytics.`qtech_bet`
(
    `bonus_type` String,
    `device` String,
    `client_type` String,
    `status` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY tuple()
SETTINGS index_granularity = 8192;
