CREATE TABLE IF NOT EXISTS analytics.`flatcashout_cashoutconfig`
(
    `won_criteria` String,
    `amount_award_rule` String,
    `channel` String,
    `status` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY tuple()
SETTINGS index_granularity = 8192;
