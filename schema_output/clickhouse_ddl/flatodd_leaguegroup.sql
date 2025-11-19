CREATE TABLE IF NOT EXISTS analytics.`flatodd_leaguegroup`
(
    `id` Int32,
    `name` String,
    `sport_type_id` Int32,
    `is_active` Bool,
    `order` Int32,
    `logo` String DEFAULT '',
    `source` Int32,
    `disabled` Bool,
    `sourceID` String DEFAULT '',
    `match_count` Int32,
    `compatability` UInt16,
    `is_locked` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
