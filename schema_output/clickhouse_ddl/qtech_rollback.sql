CREATE TABLE IF NOT EXISTS analytics.`qtech_rollback`
(
    `id` Int64,
    `reference_id` Int32,
    `qtech_txnId` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bet_id` Int64,
    `amount` Decimal64(2),
    `bonus_promo_code` String,
    `bonus_type` UInt16 DEFAULT 0,
    `client_round_id` Int32,
    `client_type` UInt16 DEFAULT 0,
    `completed` Bool,
    `currency` String,
    `device` UInt16 DEFAULT 0,
    `game_id` Int64 DEFAULT 0,
    `game_category_id` Int64 DEFAULT 0,
    `player_id` Int32,
    `qtech_created_at` DateTime64(6, 'UTC'),
    `round_id` Int32,
    `table_id` Int32,
    `deductable` Float64,
    `nonwithdrawable` Float64,
    `payable` Float64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
