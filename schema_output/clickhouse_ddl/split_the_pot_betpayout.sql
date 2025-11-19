CREATE TABLE IF NOT EXISTS analytics.`split_the_pot_betpayout`
(
    `id` Int64,
    `reference_id` Int32,
    `stp_transaction_id` Int32 DEFAULT 0,
    `stp_game_id` Int32 DEFAULT 0,
    `stp_game_kind` String DEFAULT '',
    `stp_game_variant` String DEFAULT '',
    `stp_is_free_round` Bool,
    `amount` Decimal(20,8),
    `currency` String,
    `status` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `split_the_pot_game_cycle_closed` Bool DEFAULT 0,
    `bet_id` Int64,
    `game_id` Int64,
    `player_id` Int32,
    `wallet_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
