CREATE TABLE IF NOT EXISTS analytics.`casino_bet`
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
    `stake` Decimal(20,8),
    `rollbacked_amount` Nullable(Decimal(20,8)),
    `deductable` Decimal(20,8),
    `payable` Decimal(20,8),
    `nonwithdrawable` Decimal(20,8),
    `paid_amount` Nullable(Decimal(20,8)),
    `payout_status` Int32,
    `stake_tax1` Decimal(20,8) DEFAULT 0,
    `stake_tax2` Decimal(20,8) DEFAULT 0,
    `stake_tax3` Decimal(20,8) DEFAULT 0,
    `game_id` Int32,
    `player_id` Int32,
    `wallet_id` Int32,
    `multiplier` Decimal(20,8) DEFAULT 0,
    `bet_type` Int32,
    `freebet_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
