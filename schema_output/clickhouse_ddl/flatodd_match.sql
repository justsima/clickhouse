CREATE TABLE IF NOT EXISTS analytics.`flatodd_match`
(
    `id` Int32,
    `schedule` DateTime64(6, 'UTC'),
    `local_team_id` Int32,
    `visitor_team_id` Int32,
    `league_id` Int32,
    `item_count` Int32,
    `disabled` Bool,
    `source` Int32,
    `is_active` Bool,
    `sourceID` String DEFAULT '',
    `status` UInt16,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `compatability` UInt16,
    `weighted_rank` Decimal(4,1),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
