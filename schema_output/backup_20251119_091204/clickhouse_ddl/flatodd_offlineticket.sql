CREATE TABLE IF NOT EXISTS analytics.`flatodd_offlineticket`
(
    `cashback_rule` String,
    `payment_type` String,
    `number_matches` String,
    `compatability` String,
    `cashout_rule` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY tuple()
SETTINGS index_granularity = 8192;
