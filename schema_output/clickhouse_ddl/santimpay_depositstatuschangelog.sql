CREATE TABLE IF NOT EXISTS analytics.`santimpay_depositstatuschangelog`
(
    `statuschangelog_ptr_id` Int64,
    `payment_request_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`statuschangelog_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
