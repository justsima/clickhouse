CREATE TABLE IF NOT EXISTS analytics.`flatodd_streaksetting`
(
    `id` Int32,
    `deposit` Bool,
    `withdrawal` Bool,
    `sport_bet` Bool,
    `casino_bet` Bool,
    `streak_weight` Int32,
    `description` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
