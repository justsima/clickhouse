CREATE TABLE IF NOT EXISTS analytics.`tournament_tournamentprizedistribution`
(
    `id` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `start_position` UInt32,
    `end_position` UInt32,
    `prize_amount` Nullable(Decimal(20,2)),
    `prize_type` Int32,
    `prize_description` String,
    `campaign_id` Int32,
    `image` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
