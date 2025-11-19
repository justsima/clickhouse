CREATE TABLE IF NOT EXISTS analytics.`casino_rollback`
(
    `id` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `provider_created_time` DateTime64(6, 'UTC'),
    `aggregator_created_time` DateTime64(6, 'UTC'),
    `internal_reference_id` Int32,
    `aggregator_reference_id` Int32,
    `provider_transaction_reference` String,
    `internal_round_id` Int32 DEFAULT 0,
    `provider_round_id` Int32 DEFAULT 0,
    `aggregator_round_id` Int32 DEFAULT 0,
    `game_round_closed` Bool,
    `platform` Int32 DEFAULT 0,
    `amount` Decimal(20,8),
    `currency` String,
    `status` Int32,
    `bet_id` Int32 DEFAULT 0,
    `game_id` Int32,
    `payout_id` Int32 DEFAULT 0,
    `player_id` Int32,
    `wallet_id` Int32,
    `bet_type` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
