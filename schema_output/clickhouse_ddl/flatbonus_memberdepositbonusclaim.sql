CREATE TABLE IF NOT EXISTS analytics.`flatbonus_memberdepositbonusclaim`
(
    `memberclaim_ptr_id` Int32,
    `criteria` Int32,
    `min_amount_criteria` Nullable(Decimal64(2)),
    `max_amount_criteria` Nullable(Decimal64(2)),
    `award_rule` Int16,
    `expires_on` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `claimed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`memberclaim_ptr_id`)
PARTITION BY toYYYYMM(`expires_on`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
