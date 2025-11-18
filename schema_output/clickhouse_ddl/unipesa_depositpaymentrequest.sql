CREATE TABLE IF NOT EXISTS analytics.`unipesa_depositpaymentrequest`
(
    `result_code` String,
    `unipesa_status` String,
    `service_id` String,
    `provider_id` String,
    `confirm_type` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY tuple()
SETTINGS index_granularity = 8192;
