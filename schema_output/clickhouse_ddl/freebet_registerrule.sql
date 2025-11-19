CREATE TABLE IF NOT EXISTS analytics.`freebet_registerrule`
(
    `rule_ptr_id` Int64,
    `award_rule_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`rule_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
