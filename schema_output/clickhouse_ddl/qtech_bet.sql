CREATE TABLE IF NOT EXISTS analytics.`qtech_bet`
(
    `id` Int64,
    `reference_id` Int32,
    `qtech_txnId` String,
    `round_id` Int32,
    `amount` Decimal64(2),
    `currency` String,
    `bonus_bet_amount` Decimal64(2),
    `bonus_type` UInt16 DEFAULT 0,
    `bonus_promo_code` String,
    `device` UInt16 DEFAULT 0,
    `client_type` UInt16 DEFAULT 0,
    `client_round_id` Int32,
    `qtech_created_at` DateTime64(6, 'UTC'),
    `completed` Bool,
    `table_id` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `player_id` Int32,
    `game_category_id` Int64 DEFAULT 0,
    `game_id` Int64 DEFAULT 0,
    `status` UInt16,
    `deductable` Float64,
    `nonwithdrawable` Float64,
    `payable` Float64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`qtech_created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
