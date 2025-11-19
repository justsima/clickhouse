CREATE TABLE IF NOT EXISTS analytics.`harifsport_transaction`
(
    `id` Int64,
    `typology` UInt16,
    `description` String DEFAULT '',
    `tr_id` Int32,
    `transaction_id` Int32,
    `amount_out` Decimal64(2),
    `amount_in` Decimal64(2),
    `balance` Decimal64(2),
    `date` DateTime64(6, 'UTC'),
    `player_id` Int64,
    `user_id` Int32,
    `wallet_id` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
