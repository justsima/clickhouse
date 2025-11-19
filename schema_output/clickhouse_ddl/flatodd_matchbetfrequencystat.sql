CREATE TABLE IF NOT EXISTS analytics.`flatodd_matchbetfrequencystat`
(
    `id` Int32,
    `hour_resolution` DateTime64(6, 'UTC'),
    `total_stake` Decimal(10,2),
    `frequency` Int32,
    `bet_action_type` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `match_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
