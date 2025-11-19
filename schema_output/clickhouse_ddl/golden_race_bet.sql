CREATE TABLE IF NOT EXISTS analytics.`golden_race_bet`
(
    `id` Int64,
    `reference_id` Int32,
    `amount` Decimal64(2),
    `currency` String,
    `group` String DEFAULT '',
    `goldenrace_game_cycle` String DEFAULT '',
    `goldenrace_transaction_id` Int32 DEFAULT 0,
    `goldenrace_transaction_amount` Nullable(Decimal64(2)),
    `goldenrace_transaction_category` LowCardinality(String) DEFAULT '',
    `goldenrace_timestamp` String,
    `goldenrace_request_id` Int32 DEFAULT 0,
    `status` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `payable` Float64,
    `deductable` Float64,
    `nonwithdrawable` Float64,
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
