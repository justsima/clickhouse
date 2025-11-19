CREATE TABLE IF NOT EXISTS analytics.`luckyleads_luckyleadscommissionsetting`
(
    `id` Int64,
    `registration_enabled` Bool,
    `casino_ggr_enabled` Bool,
    `sportsbook_ggr_enabled` Bool,
    `deposit_enabled` Bool,
    `first_deposit_enabled` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
