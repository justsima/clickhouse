CREATE TABLE IF NOT EXISTS analytics.`tournament_tournamentwinner`
(
    `id` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `status` Int32,
    `position` UInt32,
    `points` Decimal(20,2),
    `prize_amount` Nullable(Decimal(20,2)),
    `player_id` Int32,
    `prize_distribution_id` Int32 DEFAULT 0,
    `tournament_id` Int32,
    `prize_description` String,
    `prize_type` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
