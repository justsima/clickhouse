CREATE TABLE IF NOT EXISTS analytics.`ebirr_paymentrequest`
(
    `payment_type` String,
    `ebirr_state` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY tuple()
SETTINGS index_granularity = 8192;
