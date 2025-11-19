CREATE TABLE IF NOT EXISTS analytics.`flatcasino_rollback`
(
    `id` Int64,
    `reference` String,
    `spribe_tx_id` Int32,
    `action_id` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `action` UInt16,
    `amount` Decimal64(2),
    `bet_id` Int64 DEFAULT 0,
    `game_id` Int64,
    `payout_id` Int64 DEFAULT 0,
    `player_id` Int32,
    `provider_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
