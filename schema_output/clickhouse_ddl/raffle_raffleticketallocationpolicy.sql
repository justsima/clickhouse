CREATE TABLE IF NOT EXISTS analytics.`raffle_raffleticketallocationpolicy`
(
    `id` Int64,
    `policy` String,
    `min_deposit_amount` Nullable(Decimal(10,2)),
    `min_casino_bet_amount` Nullable(Decimal(10,2)),
    `min_sportsbook_bet_amount` Nullable(Decimal(10,2)),
    `max_tickets_per_event` UInt32,
    `on_deposit_enabled` Bool,
    `on_casino_bet_enabled` Bool,
    `on_sportsbook_bet_enabled` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
