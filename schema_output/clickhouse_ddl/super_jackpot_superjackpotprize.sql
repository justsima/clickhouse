CREATE TABLE IF NOT EXISTS analytics.`super_jackpot_superjackpotprize`
(
    `id` Int64,
    `amount` Decimal64(2),
    `number_of_winners` Int32,
    `is_awarded` Bool,
    `awarded_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `prize_rule_id` Int64,
    `super_jackpot_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
