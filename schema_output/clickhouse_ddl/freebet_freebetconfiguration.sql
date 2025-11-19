CREATE TABLE IF NOT EXISTS analytics.`freebet_freebetconfiguration`
(
    `configuration_ptr_id` Int32,
    `bet_bonus_enabled` Bool,
    `registeration_bonus_enabled` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
