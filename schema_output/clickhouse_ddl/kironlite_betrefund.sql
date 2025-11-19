CREATE TABLE IF NOT EXISTS analytics.`kironlite_betrefund`
(
    `id` Int64,
    `kiron_lite_bet_id` Int32,
    `reference_id` Int32,
    `type` LowCardinality(String),
    `amount` Decimal64(2),
    `currency` String,
    `timestamp` DateTime64(6, 'UTC'),
    `transaction_date` DateTime64(6, 'UTC'),
    `status` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `payable` Float64,
    `deductable` Float64,
    `nonwithdrawable` Float64,
    `transaction_id` Int32 DEFAULT 0,
    `bet_id` Int64,
    `game_id` Int64,
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
