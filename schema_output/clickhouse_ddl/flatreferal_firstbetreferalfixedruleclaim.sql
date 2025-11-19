CREATE TABLE IF NOT EXISTS analytics.`flatreferal_firstbetreferalfixedruleclaim`
(
    `memberclaim_ptr_id` Int32,
    `criteria` Float64,
    `referal_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`memberclaim_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
