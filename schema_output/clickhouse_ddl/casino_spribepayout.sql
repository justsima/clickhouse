CREATE TABLE IF NOT EXISTS analytics.`casino_spribepayout`
(
    `id` Int64,
    `reference` String,
    `spribe_tx_id` Int32,
    `action_id` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `paid_amount` Decimal64(2),
    `rollbacked_amount` Decimal64(2),
    `action` UInt16,
    `status` UInt16,
    `provider` String,
    `casino_bet_id` Int32,
    `casino_payout_id` Int32,
    `game_id` Int32,
    `player_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
