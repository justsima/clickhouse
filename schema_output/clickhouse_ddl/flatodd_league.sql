CREATE TABLE IF NOT EXISTS analytics.`flatodd_league`
(
    `id` Int32,
    `name` String,
    `league_group_id` Int32,
    `sport_type_id` Int32,
    `is_active` Bool,
    `order` Int32,
    `logo` String,
    `source` Int32,
    `disabled` Bool,
    `match_count` Int32,
    `item_count` Int32,
    `sourceID` String DEFAULT '',
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
